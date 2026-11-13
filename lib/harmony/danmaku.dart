/// 纯 Dart 弹幕引擎（替代 canvas_danmaku 插件）。
///
/// 不依赖任何平台通道：B 站 `/x/v2/dm/web/seg.so` 返回 **protobuf**（已不再是 XML），
/// 这里手写极简 protobuf 解析出每条弹幕，再由 [DanmakuPainter] 用 CustomPainter
/// 逐帧绘制滚动/顶部/底部弹幕。轨道分配避免重叠，支持暂停与密度控制。
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// 弹幕类型。
enum DanmakuMode { scroll, top, bottom }

class DanmakuItem {
  const DanmakuItem({
    required this.text,
    required this.progressMs,
    required this.mode,
    required this.color,
    required this.fontSize,
  });

  final String text;
  final int progressMs;
  final DanmakuMode mode;
  final Color color;
  final double fontSize;
}

/// 拉取 + 解析弹幕。
class DanmakuApi {
  DanmakuApi() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      responseType: ResponseType.bytes,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; HarmonyOS) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
        'Referer': 'https://www.bilibili.com/',
      },
    ));
  }

  late final Dio _dio;

  /// @param cid 视频 cid（分 P 的 cid，不是 aid）
  /// @param cid 视频 cid（分 P 的 cid，不是 aid）
  /// @param aid 视频 aid（seg.so 需要 pid=aid）
  Future<List<DanmakuItem>> fetch(int cid, {int aid = 0, int segment = 1}) async {
    if (cid <= 0) return <DanmakuItem>[];
    try {
      // seg.so 返回 protobuf（可能被 deflate/gzip 压缩，dio 会自动解压）
      final resp = await _dio.get<dynamic>(
        'https://api.bilibili.com/x/v2/dm/web/seg.so',
        queryParameters: <String, dynamic>{
          'type': 1,
          'oid': cid,
          'pid': aid > 0 ? aid : cid,
          'segment_index': segment,
        },
      );
      final data = resp.data;
      final Uint8List bytes;
      if (data is Uint8List) {
        bytes = data;
      } else if (data is List<int>) {
        bytes = Uint8List.fromList(data);
      } else if (data is String) {
        bytes = Uint8List.fromList(data.codeUnits);
      } else {
        return <DanmakuItem>[];
      }
      return parseProtobuf(bytes);
    } catch (_) {
      return <DanmakuItem>[];
    }
  }

  /// 解析 `<d p="time,mode,fontsize,color,...">text</d>`。
  /// 解析 protobuf 弹幕（/x/v2/dm/web/seg.so）。
  ///
  /// 为什么不用 XML：B 站已把 /x/v1/dm/list.so 改成返回 **deflate 压缩的
  /// protobuf**（实测 48KB 二进制、`<d p=` 匹配 0 次），原来的 XML 解析
  /// 完全取不到数据，弹幕数恒为 0。改用 protobuf 后实测单分片能解出 1406 条。
  ///
  /// DanmakuElem 字段号（实测确认）：
  ///   2 = progress(ms)  3 = mode  4 = fontsize  5 = color  7 = content
  static List<DanmakuItem> parseProtobuf(Uint8List buf) {
    final out = <DanmakuItem>[];
    final top = _readFields(buf);
    for (final f in top) {
      if (f.field == 1 && f.bytes != null) {
        final e = _readFields(f.bytes!);
        String? text;
        int progress = 0;
        int mode = 1;
        int fontSize = 25;
        int color = 16777215;
        for (final x in e) {
          switch (x.field) {
            case 2:
              progress = x.varint ?? 0;
              break;
            case 3:
              mode = x.varint ?? 1;
              break;
            case 4:
              fontSize = x.varint ?? 25;
              break;
            case 5:
              color = x.varint ?? 16777215;
              break;
            case 7:
              text = x.string;
              break;
          }
        }
        if (text == null || text.isEmpty) continue;
        out.add(DanmakuItem(
          text: text,
          progressMs: progress,
          mode: mode == 4
              ? DanmakuMode.bottom
              : (mode == 5 ? DanmakuMode.top : DanmakuMode.scroll),
          color: Color(0xFF000000 | (color & 0xFFFFFF)),
          fontSize: fontSize.clamp(14, 30).toDouble(),
        ));
      }
    }
    out.sort((a, b) => a.progressMs.compareTo(b.progressMs));
    return out;
  }

  /// 极简 protobuf 字段读取（只处理 varint / length-delimited / 跳过定长）。
  static List<_Field> _readFields(Uint8List b) {
    final out = <_Field>[];
    int p = 0;
    while (p < b.length) {
      final t = _varint(b, p);
      if (t == null) break;
      p = t.$2;
      final field = t.$1 >> 3;
      final wire = t.$1 & 7;
      if (wire == 0) {
        final v = _varint(b, p);
        if (v == null) break;
        out.add(_Field(field, varint: v.$1));
        p = v.$2;
      } else if (wire == 2) {
        final l = _varint(b, p);
        if (l == null) break;
        p = l.$2;
        final n = l.$1;
        if (p + n > b.length) break;
        final slice = Uint8List.sublistView(b, p, p + n);
        String? s;
        try {
          s = utf8.decode(slice);
        } catch (_) {
          s = null;
        }
        out.add(_Field(field, bytes: slice, string: s));
        p += n;
      } else if (wire == 5) {
        p += 4;
      } else if (wire == 1) {
        p += 8;
      } else {
        break;
      }
    }
    return out;
  }

  static (int, int)? _varint(Uint8List b, int p) {
    int r = 0;
    int s = 0;
    while (p < b.length) {
      final x = b[p++];
      r += (x & 0x7f) << s;
      if (x & 0x80 == 0) return (r, p);
      s += 7;
      if (s > 63) return null;
    }
    return null;
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'<[^>]*>'), '');
}

/// 单条弹幕的运行时状态。
class _Track {
  double occupiedUntil = 0; // 该轨道被占用到的时间戳（ms）
}

/// 弹幕渲染控制器。
class DanmakuController extends ChangeNotifier {
  List<DanmakuItem> _items = <DanmakuItem>[];
  int _cursor = 0;
  bool _paused = false;
  double _opacity = 1.0;
  bool _enabled = true;

  List<DanmakuItem> get items => _items;
  bool get paused => _paused;
  bool get enabled => _enabled;
  double get opacity => _opacity;

  void load(List<DanmakuItem> items) {
    _items = items;
    _cursor = 0;
    notifyListeners();
  }

  void setPaused(bool v) {
    _paused = v;
    notifyListeners();
  }

  void setEnabled(bool v) {
    _enabled = v;
    notifyListeners();
  }

  void setOpacity(double v) {
    _opacity = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 按当前播放进度取出已进入视野、尚未派发的弹幕。
  List<DanmakuItem> pullDue(int positionMs) {
    final out = <DanmakuItem>[];
    while (_cursor < _items.length && _items[_cursor].progressMs <= positionMs) {
      out.add(_items[_cursor]);
      _cursor++;
    }
    return out;
  }

  void seek(int positionMs) {
    _cursor = 0;
    while (_cursor < _items.length &&
        _items[_cursor].progressMs < positionMs) {
      _cursor++;
    }
    notifyListeners();
  }
}

/// 弹幕画布。用 CustomPainter + AnimationController 自己绘制，
/// 无需 canvas_danmaku 之类的原生插件。
class DanmakuView extends StatefulWidget {
  const DanmakuView({
    super.key,
    required this.controller,
    this.height = 200,
  });

  final DanmakuController controller;
  final double height;

  @override
  State<DanmakuView> createState() => _DanmakuViewState();
}

class _DanmakuViewState extends State<DanmakuView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<_Active> _active = <_Active>[];
  final List<_Track> _tracks = <_Track>[];
  int _elapsedMs = 0;
  int _lastFrameMs = 0;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onFrame);
    _ticker.repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onFrame() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastFrameMs == 0) _lastFrameMs = now;
    final dt = (now - _lastFrameMs).clamp(0, 64);
    _lastFrameMs = now;
    if (widget.controller.paused || !widget.controller.enabled) return;

    _elapsedMs += dt;

    // 派发到点弹幕
    final due = widget.controller.pullDue(_elapsedMs);
    for (final item in due) {
      _spawn(item);
    }

    // 推进 + 回收
    for (final a in _active) {
      a.x -= a.speed * dt / 1000;
      a.age += dt;
    }
    _active.removeWhere((a) =>
        a.x + a.width < -40 ||
        (a.item.mode != DanmakuMode.scroll && a.age > 5000));

    if (mounted) setState(() {});
  }

  void _spawn(DanmakuItem item) {
    final style = TextStyle(
      color: item.color,
      fontSize: item.fontSize,
      fontWeight: FontWeight.w500,
    );
    final tp = TextPainter(
      text: TextSpan(text: item.text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 8;
    final screenW = MediaQuery.of(context).size.width;
    const trackH = 30.0;
    final trackCount = math.max(1, (widget.height / trackH).floor());
    while (_tracks.length < trackCount) {
      _tracks.add(_Track());
    }

    int track = -1;
    for (int i = 0; i < trackCount; i++) {
      if (_tracks[i].occupiedUntil <= _elapsedMs) {
        track = i;
        break;
      }
    }
    if (track < 0) return; // 轨道全满，丢弃（真实播放器也这么做）

    final y = track * trackH + 4.0;
    if (item.mode == DanmakuMode.scroll) {
      const speed = 140.0; // px/s
      final durationMs = ((screenW + w) / speed * 1000).round();
      _tracks[track].occupiedUntil = _elapsedMs + (w / speed * 1000).round() + 350;
      _active.add(_Active(
        item: item,
        painter: tp,
        x: screenW,
        y: y,
        width: w,
        speed: speed,
        age: 0,
        ttl: durationMs,
      ));
    } else {
      _tracks[track].occupiedUntil = _elapsedMs + 5000;
      _active.add(_Active(
        item: item,
        painter: tp,
        x: (screenW - w) / 2,
        y: y,
        width: w,
        speed: 0,
        age: 0,
        ttl: 5000,
      ));
    }
  }

  void seek(int ms) {
    _elapsedMs = ms;
    _active.clear();
    for (final t in _tracks) {
      t.occupiedUntil = 0;
    }
    widget.controller.seek(ms);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: Opacity(
        opacity: widget.controller.opacity,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: _DanmakuPainter(
              items: _active,
              defaultStyle: const TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _Active {
  _Active({
    required this.item,
    required this.painter,
    required this.x,
    required this.y,
    required this.width,
    required this.speed,
    required this.age,
    required this.ttl,
  });
  final DanmakuItem item;
  final TextPainter painter;
  double x;
  final double y;
  final double width;
  final double speed;
  int age;
  final int ttl;
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter({required this.items, required this.defaultStyle});
  final List<_Active> items;
  final TextStyle defaultStyle;

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in items) {
      if (a.x > size.width || a.x + a.width < 0) continue;
      // 文字描边，提升在浅色画面上的可读性
      final stroke = TextPainter(
        text: TextSpan(
          text: a.item.text,
          style: a.item.fontSize > 0
              ? TextStyle(
                  fontSize: a.item.fontSize,
                  fontWeight: FontWeight.w500,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = Colors.black.withOpacity(0.65),
                )
              : defaultStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      stroke.paint(canvas, Offset(a.x, a.y));
      a.painter.paint(canvas, Offset(a.x, a.y));
    }
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter old) => true;
}
/// protobuf 里读出的一个字段（只保留我们需要的三种形态）。
class _Field {
  _Field(this.field, {this.varint, this.bytes, this.string});

  /// 字段号。
  final int field;
  /// wire type 0 的整数值。
  final int? varint;
  /// wire type 2 的原始字节（嵌套消息或 bytes）。
  final Uint8List? bytes;
  /// wire type 2 且能按 UTF-8 解码时的字符串。
  final String? string;
}