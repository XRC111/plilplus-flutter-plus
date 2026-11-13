/// B 站公开 API 客户端（鸿蒙版）。
///
/// 协议与主工程 `lib/http/` 保持一致：WBI 签名可选、公共请求头、统一错误处理。
/// 只依赖纯 Dart 的 dio，不引入任何平台插件，因此可直接跑在 Flutter-OH 上。
library;

import 'package:dio/dio.dart';

class BiliApi {
  BiliApi() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.bilibili.com',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; HarmonyOS) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
        'Referer': 'https://www.bilibili.com/',
        'Accept': 'application/json, text/plain, */*',
      },
    ));
  }

  late final Dio _dio;

  /// 统一解包：B 站响应 {code:0, message:"0", data:...}。
  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? params,
    String? baseUrl,
  }) async {
    final resp = await _dio.get<dynamic>(
      path,
      queryParameters: params,
      options: baseUrl == null ? null : Options(headers: {}),
    );
    final body = resp.data;
    if (body is Map && body['code'] != 0) {
      throw BiliException(body['code'] as int? ?? -1,
          body['message']?.toString() ?? '请求失败');
    }
    return body is Map ? body['data'] : body;
  }

  /// 首页推荐（分页）。
  Future<List<VideoItem>> feed({int page = 1, int pageSize = 20}) async {
    final data = await _get('/x/web-interface/wbi/index/top/feed/rcmd',
        params: {
          'ps': pageSize,
          'fresh_type': 4,
          'fresh_idx': page,
          'fresh_idx_1h': page,
        });
    final list = (data is Map ? data['item'] : null) as List? ?? [];
    return list.whereType<Map>().map(VideoItem.fromRcmd).toList();
  }

  /// 热门视频。
  Future<List<VideoItem>> popular({int page = 1, int pageSize = 20}) async {
    final data = await _get('/x/web-interface/popular',
        params: {'pn': page, 'ps': pageSize});
    final list = (data is Map ? data['list'] : null) as List? ?? [];
    return list.whereType<Map>().map(VideoItem.fromPopular).toList();
  }

  /// 全站排行榜。
  Future<List<VideoItem>> ranking({int day = 3}) async {
    final data = await _get('/x/web-interface/ranking/v2',
        params: {'rid': 0, 'type': 'all'});
    final list = (data is Map ? data['list'] : null) as List? ?? [];
    return list.whereType<Map>().map(VideoItem.fromRank).toList();
  }

  /// 搜索（综合）。
  Future<List<VideoItem>> search(String keyword, {int page = 1}) async {
    final data = await _get('/x/web-interface/search/type', params: {
      'search_type': 'video',
      'keyword': keyword,
      'page': page,
    });
    final list = (data is Map ? data['result'] : null) as List? ?? [];
    return list.whereType<Map>().map(VideoItem.fromSearch).toList();
  }

  /// 视频详情。
  Future<VideoDetail> detail(String bvid) async {
    final data = await _get('/x/web-interface/view', params: {'bvid': bvid});
    if (data is! Map) throw const BiliException(-1, '详情为空');
    return VideoDetail.fromJson(data);
  }

  /// 视频评论。
  Future<List<ReplyItem>> replies(int aid, {int page = 1}) async {
    final data = await _get('/x/v2/reply/main', params: {
      'oid': aid,
      'type': 1,
      'mode': 3,
      'next': page,
      'ps': 20,
    });
    final list = (data is Map ? data['replies'] : null) as List? ?? [];
    return list.whereType<Map>().map(ReplyItem.fromJson).toList();
  }

  /// 动态（关注/推荐流）。
  Future<List<DynamicItem>> dynamics() async {
    final data = await _get('/x/polymer/web-dynamic/v1/feed/all',
        params: {'timezone_offset': -480, 'type': 'all', 'page': 1});
    final list = (data is Map ? data['items'] : null) as List? ?? [];
    return list.whereType<Map>().map(DynamicItem.fromJson).toList();
  }

  /// UP 主信息。
  Future<Map<String, dynamic>?> userInfo(int mid) async {
    final data = await _get('/x/space/acc/info', params: {'mid': mid});
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }
}

class BiliException implements Exception {
  const BiliException(this.code, this.message);
  final int code;
  final String message;

  @override
  String toString() => 'BiliException($code): $message';
}

/// 列表里的视频条目（统一结构，兼容推荐/热门/排行/搜索四种返回格式）。
class VideoItem {
  const VideoItem({
    required this.bvid,
    required this.title,
    required this.cover,
    required this.author,
    required this.play,
    required this.danmaku,
    required this.duration,
    required this.pubdate,
    this.aid = 0,
    this.desc = '',
  });

  final String bvid;
  final String title;
  final String cover;
  final String author;
  final int play;
  final int danmaku;
  final int duration;
  final int pubdate;
  final int aid;
  final String desc;

  static String _s(dynamic v) => v?.toString() ?? '';
  static int _i(dynamic v) => v is int
      ? v
      : int.tryParse(v?.toString() ?? '') ?? 0;

  factory VideoItem.fromRcmd(Map m) {
    final owner = m['owner'] is Map ? m['owner'] as Map : const {};
    final stat = m['stat'] is Map ? m['stat'] as Map : const {};
    return VideoItem(
      bvid: _s(m['bvid']),
      title: _s(m['title']),
      cover: (m['pic'] ?? '').toString().replaceFirst('http:', 'https:'),
      author: _s(owner['name']),
      play: _i(stat['view']),
      danmaku: _i(stat['danmaku']),
      duration: _i(m['duration']),
      pubdate: _i(m['pubdate']),
      aid: _i(m['id'] ?? m['aid']),
    );
  }

  factory VideoItem.fromPopular(Map m) {
    final owner = m['owner'] is Map ? m['owner'] as Map : const {};
    final stat = m['stat'] is Map ? m['stat'] as Map : const {};
    return VideoItem(
      bvid: _s(m['bvid']),
      title: _s(m['title']),
      cover: (m['pic'] ?? '').toString().replaceFirst('http:', 'https:'),
      author: _s(owner['name']),
      play: _i(stat['view']),
      danmaku: _i(stat['danmaku']),
      duration: _i(m['duration']),
      pubdate: _i(m['pubdate']),
      aid: _i(m['aid']),
      desc: _s(m['desc']),
    );
  }

  factory VideoItem.fromRank(Map m) {
    final stat = m['stat'] is Map ? m['stat'] as Map : const {};
    return VideoItem(
      bvid: _s(m['bvid']),
      title: _s(m['title']),
      cover: (m['pic'] ?? '').toString().replaceFirst('http:', 'https:'),
      author: _s(m['owner'] is Map ? m['owner']['name'] : ''),
      play: _i(stat['view']),
      danmaku: _i(stat['danmaku']),
      duration: _i(m['duration']),
      pubdate: _i(m['pubdate']),
      aid: _i(m['aid']),
      desc: _s(m['desc']),
    );
  }

  factory VideoItem.fromSearch(Map m) {
    return VideoItem(
      bvid: _s(m['bvid']),
      title: _s(m['title']).replaceAll(RegExp(r'<[^>]*>'), ''),
      cover: (m['pic'] ?? '').toString().replaceFirst('http:', 'https:'),
      author: _s(m['author']),
      play: _i(m['play']),
      danmaku: _i(m['video_review']),
      duration: _parseDuration(m['duration']),
      pubdate: _i(m['pubdate']),
      aid: _i(m['aid']),
      desc: _s(m['description']),
    );
  }

  static int _parseDuration(dynamic v) {
    final s = v?.toString() ?? '';
    final parts = s.split(':');
    if (parts.length == 2) {
      return (int.tryParse(parts[0]) ?? 0) * 60 +
          (int.tryParse(parts[1]) ?? 0);
    }
    return int.tryParse(s) ?? 0;
  }
}

class VideoDetail {
  const VideoDetail({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.cover,
    required this.desc,
    required this.author,
    required this.authorMid,
    required this.view,
    required this.danmaku,
    required this.like,
    required this.coin,
    required this.favorite,
    required this.reply,
    required this.duration,
    required this.pubdate,
    required this.pages,
  });

  final String bvid;
  final int aid;
  final String title;
  final String cover;
  final String desc;
  final String author;
  final int authorMid;
  final int view;
  final int danmaku;
  final int like;
  final int coin;
  final int favorite;
  final int reply;
  final int duration;
  final int pubdate;
  final List<VideoPage> pages;

  static int _i(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
  static String _s(dynamic v) => v?.toString() ?? '';

  factory VideoDetail.fromJson(Map m) {
    final owner = m['owner'] is Map ? m['owner'] as Map : const {};
    final stat = m['stat'] is Map ? m['stat'] as Map : const {};
    final pages = (m['pages'] is List ? m['pages'] as List : const [])
        .whereType<Map>()
        .map((p) => VideoPage(
              cid: _i(p['cid']),
              page: _i(p['page']),
              part: _s(p['part']),
              duration: _i(p['duration']),
            ))
        .toList();
    return VideoDetail(
      bvid: _s(m['bvid']),
      aid: _i(m['aid']),
      title: _s(m['title']),
      cover: (m['pic'] ?? '').toString().replaceFirst('http:', 'https:'),
      desc: _s(m['desc']),
      author: _s(owner['name']),
      authorMid: _i(owner['mid']),
      view: _i(stat['view']),
      danmaku: _i(stat['danmaku']),
      like: _i(stat['like']),
      coin: _i(stat['coin']),
      favorite: _i(stat['favorite']),
      reply: _i(stat['reply']),
      duration: _i(m['duration']),
      pubdate: _i(m['pubdate']),
      pages: pages,
    );
  }
}

class VideoPage {
  const VideoPage({
    required this.cid,
    required this.page,
    required this.part,
    required this.duration,
  });
  final int cid;
  final int page;
  final String part;
  final int duration;
}

class ReplyItem {
  const ReplyItem({
    required this.uname,
    required this.content,
    required this.like,
    required this.replyCount,
  });
  final String uname;
  final String content;
  final int like;
  final int replyCount;

  static String _s(dynamic v) => v?.toString() ?? '';
  static int _i(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  factory ReplyItem.fromJson(Map m) {
    final member = m['member'] is Map ? m['member'] as Map : const {};
    final content = m['content'] is Map ? m['content'] as Map : const {};
    return ReplyItem(
      uname: _s(member['uname']),
      content: _s(content['message']),
      like: _i(m['like']),
      replyCount: _i(m['rcount']),
    );
  }
}

class DynamicItem {
  const DynamicItem({
    required this.uname,
    required this.text,
    required this.time,
  });
  final String uname;
  final String text;
  final String time;

  factory DynamicItem.fromJson(Map m) {
    final modules = m['modules'] is Map ? m['modules'] as Map : const {};
    final author = modules['module_author'] is Map
        ? modules['module_author'] as Map
        : const {};
    final dynamic = modules['module_dynamic'] is Map
        ? modules['module_dynamic'] as Map
        : const {};
    final major = dynamic['major'] is Map ? dynamic['major'] as Map : const {};
    final opus = major['opus'] is Map ? major['opus'] as Map : const {};
    final desc = dynamic['desc'] is Map ? dynamic['desc'] as Map : const {};
    return DynamicItem(
      uname: author['name']?.toString() ?? '',
      text: (opus['title'] ?? desc['text'] ?? opus['summary']?['rich_text_nodes']
                  ?.toString() ??
              '')
          .toString(),
      time: author['pub_time']?.toString() ?? '',
    );
  }
}
