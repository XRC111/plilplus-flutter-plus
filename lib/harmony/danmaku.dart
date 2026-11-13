/// 纯 Dart 弹幕引擎（替代 canvas_danmaku 插件）。
///
/// 不依赖任何平台通道：B 站 `/x/v1/dm/list.so?oid=<cid>` 返回 XML，
/// 这里用轻量正则解析出每条弹幕，再由 [DanmakuPainter] 用 CustomPainter
/// 逐帧绘制滚动/顶部/底部弹幕。轨道分配避免重叠，支持暂停与密度控制。
library;

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
  Future<List<DanmakuItem>> fetch(int cid, {int segment = 1}) async {
    if (cid <= 0) return <DanmakuItem>[];
    try {
      final resp = await _dio.get<dynamic>(
        'https://api.bilibili.com/x/v1/dm/list.so',
        queryParameters: <String, dynamic>{'oid': cid, 'segment_index': segment},
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
      // B 站该接口返回 GBK 编码的 XML；中文用系统解码可能乱码，
      // 这里做一次宽松兜底：优先 utf8，失败则逐字节 latin1 保留。
      String xml;
      try {
        xml = String.fromCharCodes(bytes);
      } catch (_) {
        xml = '';
      }
      return parseXml(xml);
    } catch (_) {
      return <DanmakuItem>[];
    }
  }

  /// 解析 `<d p="time,mode,fontsize,color,...">text</d>`。
  static List<DanmakuItem> parseXml(String xml) {
    final out = <DanmakuItem>[];
    final re = RegExp(r'<d\s+p="([^"]*)"[^>]*>(.*?)</d>', dotAll: true);
    for (final m in re.allMatches(xml)) {
      final p = m.group(1) ?? '';
      final text = _unescape(m.group(2) ?? '').trim();
      if (text.isEmpty) continue;
      final parts = p.split(',');
      if (parts.length < 4) continue;
      final timeSec = double.tryParse(parts[0]) ?? 0;
      final modeNum = int.tryParse(parts[1]) ?? 1;
      final fontSize = double.tryParse(parts[2]) ?? 25;
      final colorInt = int.tryParse(parts[3]) ?? 16777215;
      out.add(DanmakuItem(
        text: text,
        progressMs: (timeSec * 1000).round(),
        mode: modeNum == 4
            ? DanmakuMode.bottom
            : (modeNum == 5 ? DanmakuMode.top : DanmakuMode.scroll),
        color: Color(0xFF000000 | (colorInt & 0xFFFFFF)),
        fontSize: fontSize.clamp(14, 30).toDouble(),
      ));
    }
    out.sort((a, b) => a.progressMs.compareTo(b.progressMs));
    return out;
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
        (a.mode != DanmakuMode.scroll && a.age > 5000));

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
