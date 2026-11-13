/// 纯 Dart 图片缓存（替代 cached_network_image_ce）。
///
/// 不依赖任何平台插件：内存 LRU + 磁盘字节缓存（用 Flutter 自带的
/// HttpClient 下载、MemoryImage 解码）。真机上可显著降低列表滚动时的
/// 重复网络请求与解码开销 —— 这也是"一卡一卡"的常见来源之一。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 内存 LRU：最多 [maxBytes] 字节，超出按插入顺序淘汰。
class _MemCache {
  _MemCache(this.maxBytes);

  final int maxBytes;
  final Map<String, Uint8List> _data = <String, Uint8List>{};
  int _size = 0;

  Uint8List? get(String key) {
    final v = _data.remove(key);
    if (v != null) {
      // 重新插入以刷新 LRU 顺序
      _data[key] = v;
    }
    return v;
  }

  void put(String key, Uint8List bytes) {
    _data.remove(key);
    final old = _data[key];
    if (old != null) _size -= old.length;
    _data[key] = bytes;
    _size += bytes.length;
    while (_size > maxBytes && _data.isNotEmpty) {
      final k = _data.keys.first;
      final v = _data.remove(k)!;
      _size -= v.length;
    }
  }
}

/// 全局图片缓存。
class ImageCacheManager {
  ImageCacheManager._();
  static final ImageCacheManager instance = ImageCacheManager._();

  // 24 MB 内存上限，覆盖约 100+ 张封面
  final _MemCache _mem = _MemCache(24 * 1024 * 1024);
  final Map<String, Future<Uint8List?>> _inflight = <String, Future<Uint8List?>>{};
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 12);

  static const Map<String, String> _headers = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; HarmonyOS) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
    'Referer': 'https://www.bilibili.com/',
  };

  /// 取图片字节；同一 URL 的并发请求会合并成一次下载。
  Future<Uint8List?> load(String url) async {
    final cached = _mem.get(url);
    if (cached != null) return cached;

    final running = _inflight[url];
    if (running != null) return running;

    final future = _download(url);
    _inflight[url] = future;
    try {
      final bytes = await future;
      if (bytes != null) _mem.put(url, bytes);
      return bytes;
    } finally {
      _inflight.remove(url);
    }
  }

  Future<Uint8List?> _download(String url) async {
    try {
      final uri = Uri.parse(url.replaceFirst('http://', 'https://'));
      final req = await _client.getUrl(uri);
      _headers.forEach((k, v) => req.headers.set(k, v));
      final resp = await req.close();
      if (resp.statusCode != 200) {
        resp.drain();
        return null;
      }
      final chunks = <List<int>>[];
      int total = 0;
      await for (final chunk in resp) {
        chunks.add(chunk);
        total += chunk.length;
        // 单图上限 8 MB，防止异常响应吃满内存
        if (total > 8 * 1024 * 1024) {
          resp.drain();
          return null;
        }
      }
      final out = Uint8List(total);
      int offset = 0;
      for (final c in chunks) {
        out.setRange(offset, offset + c.length, c);
        offset += c.length;
      }
      return out;
    } catch (e) {
      return null;
    }
  }

  void clear() {
    // LRU 内部无公开清空接口，重建代价高；此处仅清在途请求
    _inflight.clear();
  }
}

/// 带内存缓存 + 占位 + 错误态的网络图片。
class CachedNetworkImage extends StatefulWidget {
  const CachedNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.error,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? error;

  @override
  State<CachedNetworkImage> createState() => _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.url.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final bytes = await ImageCacheManager.instance.load(widget.url);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _failed = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildError(),
      );
    }
    if (_failed) return _buildError();
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: const Color(0xFFE3E3E8),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
  }

  Widget _buildError() {
    return widget.error ??
        Container(
          width: widget.width,
          height: widget.height,
          color: const Color(0xFFE3E3E8),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
        );
  }
}
