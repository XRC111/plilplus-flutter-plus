/// 双列瀑布流视频卡片（对齐 B 站官方首页样式）。
///
/// 官方卡片结构（从上到下）：
///   封面（16:9，右下角时长角标）
///   标题（2 行，14sp）
///   [竖屏] UP 主名 ... ⋮
///   播放量 + 弹幕数
///
/// 这里只依赖纯 Flutter + 自研 CachedNetworkImage，不引入任何插件。
library;

import 'package:flutter/material.dart';

import 'api.dart';
import 'image_cache.dart';
import 'pili_ui.dart';

class VideoGridCard extends StatelessWidget {
  const VideoGridCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final VideoItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PiliMetric.radiusCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(PiliMetric.radiusCard),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.cover.isNotEmpty)
                    CachedNetworkImage(url: item.cover, fit: BoxFit.cover)
                  else
                    Container(color: PiliColor.surfaceAlt),
                  if (item.duration > 0)
                    CornerBadge(text: formatDuration(item.duration)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PiliColor.text,
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              // 竖屏标签：B 站官方对竖版视频会标一个「竖屏」
              if (item.duration > 0 && item.duration < 120)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: MiniChip(text: '竖屏'),
                ),
              Expanded(
                child: Text(
                  item.author.isEmpty ? 'UP 主' : item.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PiliColor.textSub,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.play_arrow_rounded,
                  size: 13, color: PiliColor.textWeak),
              const SizedBox(width: 1),
              Text(
                formatCount(item.play),
                style: const TextStyle(color: PiliColor.textWeak, fontSize: 11),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.subtitles_outlined,
                  size: 12, color: PiliColor.textWeak),
              const SizedBox(width: 1),
              Text(
                formatCount(item.danmaku),
                style: const TextStyle(color: PiliColor.textWeak, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 双列网格（两列，间距对齐官方）。
///
/// 用 SliverGrid 是为了能嵌进 CustomScrollView，方便以后加头部轮播/分区。
class VideoGridSliver extends StatelessWidget {
  const VideoGridSliver({
    super.key,
    required this.items,
    required this.onTapItem,
  });

  final List<VideoItem> items;
  final void Function(VideoItem) onTapItem;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: PiliMetric.gapPage),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 10,
          // 封面 16:9 + 标题 2 行 + UP 主 + 数据，实测这个比例刚好不溢出
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final item = items[i];
            return VideoGridCard(
              item: item,
              onTap: () => onTapItem(item),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}
