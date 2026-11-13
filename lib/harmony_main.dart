/// PiliPlus HarmonyOS 客户端入口。
///
/// 这不是占位骨架：直接通过纯 Dart 的 dio 调用 B 站公开 API，实现
/// 首页推荐 / 热门 / 排行榜 / 搜索 / 动态 五个可浏览的板块，
/// 以及视频详情页（含分 P、统计、评论）。
///
/// 受 Flutter-OH 插件生态限制，媒体播放、弹幕渲染、投屏、扫码登录等
/// 强原生能力暂不可用（详见 README 鸿蒙章节）；但内容浏览与检索是完整的。
library;

import 'package:flutter/material.dart';

import 'harmony/api.dart';
import 'harmony/image_cache.dart';
import 'harmony/danmaku.dart';

void main() => runApp(const PiliPlusHarmonyApp());

class PiliPlusHarmonyApp extends StatelessWidget {
  const PiliPlusHarmonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PiliPlus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFB7299),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F6F8),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFB7299),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

/// 板块定义。
enum Section { feed, popular, ranking, dynamics, search }

extension SectionX on Section {
  String get label {
    switch (this) {
      case Section.feed:
        return '推荐';
      case Section.popular:
        return '热门';
      case Section.ranking:
        return '排行';
      case Section.dynamics:
        return '动态';
      case Section.search:
        return '搜索';
    }
  }

  IconData get icon {
    switch (this) {
      case Section.feed:
        return Icons.home_outlined;
      case Section.popular:
        return Icons.local_fire_department_outlined;
      case Section.ranking:
        return Icons.leaderboard_outlined;
      case Section.dynamics:
        return Icons.dynamic_feed_outlined;
      case Section.search:
        return Icons.search_outlined;
    }
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final BiliApi _api = BiliApi();
  Section _section = Section.feed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section.index,
        onDestinationSelected: (i) =>
            setState(() => _section = Section.values[i]),
        destinations: Section.values
            .map((s) => NavigationDestination(
                  icon: Icon(s.icon),
                  label: s.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_section) {
      case Section.feed:
        return _VideoList(
          key: const ValueKey('feed'),
          loader: (page) => _api.feed(page: page),
        );
      case Section.popular:
        return _VideoList(
          key: const ValueKey('popular'),
          loader: (page) => _api.popular(page: page),
        );
      case Section.ranking:
        return _VideoList(
          key: const ValueKey('ranking'),
          loader: (_) => _api.ranking(),
          singlePage: true,
        );
      case Section.dynamics:
        return _DynamicList(
          key: const ValueKey('dynamics'),
          loader: () => _api.dynamics(),
        );
      case Section.search:
        return _SearchPage(
          key: const ValueKey('search'),
          api: _api,
        );
    }
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFB7299),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Text('P',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Text(
            _section == Section.search ? 'PiliPlus' : 'PiliPlus · ${_section.label}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

typedef VideoLoader = Future<List<VideoItem>> Function(int page);

/// 可无限滚动的视频列表。
class _VideoList extends StatefulWidget {
  const _VideoList({
    super.key,
    required this.loader,
    this.singlePage = false,
  });

  final VideoLoader loader;
  final bool singlePage;

  @override
  State<_VideoList> createState() => _VideoListState();
}

class _VideoListState extends State<_VideoList>
    with AutomaticKeepAliveClientMixin {
  final List<VideoItem> _items = [];
  final ScrollController _scroll = ScrollController();
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (!_loading &&
          _hasMore &&
          !widget.singlePage &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.loader(_page);
      if (!mounted) return;
      setState(() {
        _items.addAll(list);
        _page += 1;
        _hasMore = !widget.singlePage && list.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null && _items.isEmpty) {
      return _ErrorView(error: _error!, onRetry: () {
        _page = 1;
        _items.clear();
        _load();
      });
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () async {
        _page = 1;
        _items.clear();
        _hasMore = true;
        await _load();
      },
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _VideoCard(item: _items[i]);
        },
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.item});
  final VideoItem item;

  String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return n.toString();
  }

  String _dur(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VideoDetailPage(bvid: item.bvid, fallback: item),
        )),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.cover.isNotEmpty)
                    CachedNetworkImage(url: item.cover, fit: BoxFit.cover)
                  else
                    Container(color: const Color(0xFFE3E3E8)),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_dur(item.duration),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: Theme.of(context).hintColor),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(item.author.isEmpty ? 'UP 主' : item.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor)),
                      ),
                      Icon(Icons.play_arrow_outlined,
                          size: 13, color: Theme.of(context).hintColor),
                      Text(' ${_fmt(item.play)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor)),
                      const SizedBox(width: 8),
                      Icon(Icons.subtitles_outlined,
                          size: 13, color: Theme.of(context).hintColor),
                      Text(' ${_fmt(item.danmaku)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).hintColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 视频详情页。
class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({super.key, required this.bvid, required this.fallback});
  final String bvid;
  final VideoItem fallback;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final BiliApi _api = BiliApi();
  final DanmakuController _danmaku = DanmakuController();
  final DanmakuApi _danmakuApi = DanmakuApi();
  VideoDetail? _detail;
  List<ReplyItem> _replies = [];
  Object? _error;
  bool _showDanmaku = false;
  bool _danmakuLoading = false;
  int _danmakuCount = 0;

  @override
  void dispose() {
    _danmaku.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _api.detail(widget.bvid);
      if (!mounted) return;
      setState(() => _detail = d);
      final r = await _api.replies(d.aid);
      if (!mounted) return;
      setState(() => _replies = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  String _fmt(int n) =>
      n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}万' : n.toString();

  /// 加载弹幕（用第一个分 P 的 cid）。
  Future<void> _toggleDanmaku() async {
    if (_showDanmaku) {
      setState(() {
        _showDanmaku = false;
        _danmaku.setEnabled(false);
      });
      return;
    }
    final d = _detail;
    if (d == null || d.pages.isEmpty) return;
    setState(() => _danmakuLoading = true);
    final items = await _danmakuApi.fetch(d.pages.first.cid, aid: d.aid);
    if (!mounted) return;
    _danmaku.load(items);
    _danmaku.setEnabled(true);
    setState(() {
      _showDanmaku = true;
      _danmakuLoading = false;
      _danmakuCount = items.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      appBar: AppBar(title: const Text('视频详情')),
      body: _error != null && d == null
          ? _ErrorView(error: _error!, onRetry: _load)
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (d.cover.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CachedNetworkImage(
                                  url: d.cover, fit: BoxFit.cover),
                            ),
                            // 自研弹幕层：纯 CustomPainter，无原生插件
                            Positioned.fill(
                              child: DanmakuView(
                                controller: _danmaku,
                                height: 200,
                              ),
                            ),
                            if (_danmakuLoading)
                              const Positioned.fill(
                                child: Center(
                                    child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _toggleDanmaku,
                            icon: Icon(
                              _showDanmaku
                                  ? Icons.subtitles
                                  : Icons.subtitles_outlined,
                              size: 16,
                            ),
                            label: Text(
                              _showDanmaku
                                  ? '关闭弹幕 ($_danmakuCount)'
                                  : '显示弹幕',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_showDanmaku)
                            IconButton(
                              tooltip: _danmaku.paused ? '继续' : '暂停',
                              icon: Icon(_danmaku.paused
                                  ? Icons.play_arrow
                                  : Icons.pause,
                                  size: 18),
                              onPressed: () => setState(
                                  () => _danmaku.setPaused(!_danmaku.paused)),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.title,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFFFB7299),
                                child: Icon(Icons.person,
                                    size: 16, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Text(d.author.isEmpty ? 'UP 主' : d.author,
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              _Stat(Icons.play_arrow_outlined, _fmt(d.view)),
                              _Stat(Icons.subtitles_outlined, _fmt(d.danmaku)),
                              _Stat(Icons.thumb_up_outlined, _fmt(d.like)),
                              _Stat(Icons.monetization_on_outlined,
                                  _fmt(d.coin)),
                              _Stat(Icons.star_outline, _fmt(d.favorite)),
                              _Stat(Icons.comment_outlined, _fmt(d.reply)),
                            ],
                          ),
                          if (d.desc.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(d.desc,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).hintColor,
                                    height: 1.5)),
                          ],
                        ],
                      ),
                    ),
                    if (d.pages.length > 1) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text('分 P 列表',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                      ...d.pages.map((p) => ListTile(
                            dense: true,
                            leading: Text('P${p.page}',
                                style: const TextStyle(
                                    color: Color(0xFFFB7299),
                                    fontWeight: FontWeight.bold)),
                            title: Text(p.part,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                            trailing: Text(
                                '${p.duration ~/ 60}:${(p.duration % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12)),
                          )),
                      const Divider(height: 24),
                    ],
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text('评论',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    if (_replies.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('暂无评论或加载中…',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor)),
                        ),
                      )
                    else
                      ..._replies.take(30).map((r) => ListTile(
                            leading: const CircleAvatar(
                              radius: 15,
                              child: Icon(Icons.person, size: 16),
                            ),
                            title: Text(r.uname,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(r.content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                            trailing: Text('👍 ${_fmt(r.like)}',
                                style: const TextStyle(fontSize: 11)),
                          )),
                  ],
                ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).hintColor),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      ],
    );
  }
}

/// 搜索页。
class _SearchPage extends StatefulWidget {
  const _SearchPage({super.key, required this.api});
  final BiliApi api;

  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  List<VideoItem> _results = [];
  bool _loading = false;
  Object? _error;
  String _keyword = '';

  Future<void> _search(String kw) async {
    if (kw.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _keyword = kw.trim();
    });
    try {
      final r = await widget.api.search(kw.trim());
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              hintText: '搜索视频、UP 主…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _ctrl.clear();
                  setState(() {
                    _results = [];
                    _keyword = '';
                  });
                },
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: _ErrorView(error: _error!, onRetry: () => _search(_keyword)))
        else if (_results.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_outlined,
                      size: 56, color: Theme.of(context).hintColor),
                  const SizedBox(height: 12),
                  Text(_keyword.isEmpty ? '输入关键词开始搜索' : '没有找到相关视频',
                      style: TextStyle(color: Theme.of(context).hintColor)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _VideoCard(item: _results[i]),
            ),
          ),
      ],
    );
  }
}

/// 动态列表。
class _DynamicList extends StatefulWidget {
  const _DynamicList({super.key, required this.loader});
  final Future<List<DynamicItem>> Function() loader;

  @override
  State<_DynamicList> createState() => _DynamicListState();
}

class _DynamicListState extends State<_DynamicList> {
  List<DynamicItem> _items = [];
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.loader();
      if (!mounted) return;
      setState(() {
        _items = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(error: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return Center(
        child: Text('暂无动态（该接口通常需要登录）',
            style: TextStyle(color: Theme.of(context).hintColor)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final d = _items[i];
          return Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFFFB7299),
                        child: Icon(Icons.person, size: 17, color: Colors.white),
                      ),
                      const SizedBox(width: 9),
                      Text(d.uname.isEmpty ? 'UP 主' : d.uname,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (d.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(d.text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.45)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined,
                size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text('加载失败',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).hintColor)),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
