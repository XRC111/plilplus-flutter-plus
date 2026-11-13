/// 视频播放页。
///
/// 用官方 federated 插件 video_player + OpenHarmony-SIG 的 video_player_ohos
/// 实现（AVPlayer）。播放地址来自 /x/player/playurl 的 durl 单 MP4 直链，
/// 无需登录、无需 DASH 合成。
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'api.dart';
import 'video_proxy.dart';

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

      // 先用 dio 探测 CDN（只取 1 字节），确认直链本身可用。
      // 用主工程同款 BiliDroid UA + Referer：实测 206。
      String probe = '未探测';
      try {
        final r = await _api.probeUrl(url, <String, String>{
          'User-Agent': 'Bilibili Freedoooooom/MarkII',
          'Referer': 'https://www.bilibili.com/',
        });
        probe = 'CDN HTTP $r';
      } catch (e) {
        probe = 'CDN 探测失败: $e';
      }
      _probe = probe;
      if (mounted) setState(() {});

      // 关键：不把 httpHeaders 传给 AVPlayer。
      // SIG 插件一旦收到 headers 就会调 setMediaSource，而该接口只能在 idle
      // 状态调用，插件却先设了 avPlayer.url，必然报 videoError。
      // 改由本地代理补 Referer/UA，AVPlayer 只播 127.0.0.1 的普通 URL。
      final local = await VideoProxy.instance.start(url);
      _probe = '$probe | 代理 $local';
      if (mounted) setState(() {});

      final c = VideoPlayerController.networkUrl(Uri.parse(local));
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
    // 关掉本地代理，避免端口泄漏
    VideoProxy.instance.stop();
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
