/// 本地 HTTP 代理：给 B 站视频直链补 Referer/UA 后再喂给 AVPlayer。
///
/// 为什么需要：B 站 CDN 强制校验 Referer + UA；而 SIG 的 video_player_ohos
/// 一旦传 httpHeaders 就会走 `setMediaSource`，该接口按官方文档**只能在 idle
/// 状态调用**，但插件是先 `avPlayer.url = ...` 再调它，必然报 videoError。
/// 于是改成：App 内起一个本地 HttpServer，AVPlayer 播 http://127.0.0.1:port/，
/// 代理收到请求后转发到真实 CDN 并补上 Referer/UA。AVPlayer 看到的是普通本地
/// URL（无需 headers），完全绕开 setMediaSource 路径。
library;

import 'dart:io';

import 'package:dio/dio.dart';

class VideoProxy {
  VideoProxy._();
  static final VideoProxy instance = VideoProxy._();

  HttpServer? _server;
  String? _target;
  int? _port;

  static const String _ua = 'Bilibili Freedoooooom/MarkII';

  /// 启动代理并返回本地播放地址。同一个 target 复用已启动的服务。
  Future<String> start(String target) async {
    if (_server != null && _target == target && _port != null) {
      return 'http://127.0.0.1:$_port/';
    }
    await stop();
    _target = target;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _port = server.port;
    // 不 await，让服务在后台跑
    server.listen(_handle);
    return 'http://127.0.0.1:$_port/';
  }

  Future<void> _handle(HttpRequest req) async {
    final target = _target;
    if (target == null) {
      req.response.statusCode = HttpStatus.internalServerError;
      await req.response.close();
      return;
    }
    try {
      // 透传 Range（拖动进度条依赖它）
      final headers = <String, String>{
        'User-Agent': _ua,
        'Referer': 'https://www.bilibili.com/',
      };
      final range = req.headers.value('range');
      if (range != null && range.isNotEmpty) {
        headers['Range'] = range;
      }
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.stream,
        validateStatus: (int? s) => s != null && s < 500,
      ));
      final resp = await dio.get<ResponseBody>(
        target,
        options: Options(headers: headers, responseType: ResponseType.stream),
      );
      final data = resp.data;
      if (data == null) {
        req.response.statusCode = HttpStatus.badGateway;
        await req.response.close();
        return;
      }
      req.response.statusCode = resp.statusCode ?? HttpStatus.ok;
      // 关键头透传，AVPlayer 靠这些判断时长/是否支持 Range
      for (final key in const [
        'content-type',
        'content-length',
        'content-range',
        'accept-ranges',
      ]) {
        final v = resp.headers.value(key);
        if (v != null) {
          req.response.headers.set(key, v);
        }
      }
      await req.response.addStream(data.stream);
      await req.response.close();
    } catch (e) {
      try {
        req.response.statusCode = HttpStatus.badGateway;
        await req.response.close();
      } catch (_) {
        // 客户端已断开
      }
    }
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    _target = null;
    if (s != null) {
      await s.close(force: true);
    }
  }
}
