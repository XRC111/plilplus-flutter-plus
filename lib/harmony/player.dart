/// 视频播放页。
///
/// 用官方 federated 插件 video_player + OpenHarmony-SIG 的 video_player_ohos
/// 实现（AVPlayer）。播放地址来自 /x/player/playurl 的 durl 单 MP4 直链，
/// 无需登录、无需 DASH 合成。
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'api.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.bvid,
    required this.aid,
    required this.cid,
    required this.title,
    required this.cover,
  });

  final String bvid;
  final int aid;
  final int cid;
  final String title;
  final String cover;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final BiliApi _api = BiliApi();
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;
  bool _initialized = false;
  String _probe = '未探测';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final url = await _api.playUrl(widget.aid, widget.cid);
      if (!mounted) return;
      // B 站视频 CDN 强制校验 Referer / UA，缺了会 403。
      // SIG 插件的 create() 会把 httpHeaders 透传给原生层（见
      // VideoPlayer.createAVPlayer 里的 createMediaSourceWithUrl）。
      final headers = <String, String>{
        'Referer': 'https://www.bilibili.com/',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; HarmonyOS) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
      };

      // 先用 dio 探测 CDN 是否可达（只取前 1 字节），把真实 HTTP 码记下来。
      // AVPlayer 的错误信息太笼统（"video player had error!"），
      // 有这个探测就能区分「CDN 拒绝」和「AVPlayer 解码/状态机问题」。
      String probe = '未探测';
      try {
        final r = await _api.probeUrl(url, headers);
        probe = 'CDN HTTP $r';
      } catch (e) {
        probe = 'CDN 探测失败: $e';
      }
      _probe = probe;
      if (mounted) setState(() {});

      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );
      _controller = c;
      await c.initialize();
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _loading = false;
      });
      c.play();
      c.addListener(() {
        if (c.value.hasError && mounted) {
          setState(() => _error = '播放错误：${c.value.errorDescription}');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 40),
                        const SizedBox(height: 12),
                        Text('无法播放：$_error',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text(_probe,
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 12)),
                      ],
                    ),
                  )
                : _initialized && _controller != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                          const SizedBox(height: 16),
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 36,
                                color: Colors.white,
                                icon: Icon(_controller!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                onPressed: () {
                                  setState(() {
                                    _controller!.value.isPlaying
                                        ? _controller!.pause()
                                        : _controller!.play();
                                  });
                                },
                              ),
                              const SizedBox(width: 24),
                              IconButton(
                                iconSize: 30,
                                color: Colors.white,
                                icon: const Icon(Icons.replay_10),
                                onPressed: () {
                                  final p = _controller!.value.position;
                                  _controller!.seekTo(
                                    p - const Duration(seconds: 10) < Duration.zero
                                        ? Duration.zero
                                        : p - const Duration(seconds: 10),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                iconSize: 30,
                                color: Colors.white,
                                icon: const Icon(Icons.forward_10),
                                onPressed: () {
                                  final p = _controller!.value.position;
                                  final d = _controller!.value.duration;
                                  final t = p + const Duration(seconds: 10);
                                  _controller!.seekTo(t > d ? d : t);
                                },
                              ),
                            ],
                          ),
                        ],
                      )
                    : const Text('播放器未就绪',
                        style: TextStyle(color: Colors.white70)),
      ),
    );
  }
}
