/// PiliPlus 鸿蒙版的视觉层：主题、颜色、间距、卡片。
///
/// 为什么单独抽文件：主入口 harmony_main.dart 已经很长，
/// 配色和卡片样式是跨页面复用的（首页/热门/排行/搜索/详情都用），
/// 抽出来以后调视觉只需要改这里。
library;

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// B 站官方主色（粉）+ 深色背景。
abstract final class PiliColor {
  /// 主色：官方粉。
  static const Color primary = Color(0xFFFB7299);
  /// 主色的浅一档，用于选中态底。
  static const Color primarySoft = Color(0x33FB7299);

  /// 深色页面背景（官方是 #17181A 一类）。
  static const Color bg = Color(0xFF17181A);
  /// 卡片/次级面。
  static const Color surface = Color(0xFF1F2123);
  /// 再浅一档（标签、胶囊）。
  static const Color surfaceAlt = Color(0xFF2A2D30);

  /// 主文字。
  static const Color text = Color(0xFFE9EAEC);
  /// 次要文字（UP 主、播放量）。
  static const Color textSub = Color(0xFF9BA0A6);
  /// 更弱（时长角标旁的说明）。
  static const Color textWeak = Color(0xFF6E747B);

  /// 分割线。
  static const Color divider = Color(0xFF2C2F32);
}

/// 全局圆角/间距常量，避免各处硬编码不一致。
abstract final class PiliMetric {
  static const double radiusCard = 8;
  static const double radiusChip = 6;
  static const double gapPage = 12;
  static const double gapCard = 8;
}

/// 全局主题。
ThemeData buildPiliTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: PiliColor.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: PiliColor.primary,
      surface: PiliColor.surface,
      onSurface: PiliColor.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PiliColor.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: PiliColor.text,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: PiliColor.text),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: PiliColor.text,
      displayColor: PiliColor.text,
    ),
    dividerColor: PiliColor.divider,
    splashFactory: InkSparkle.splashFactory,
  );
}

/// 播放量/弹幕数的短格式：10000 -> 1.0万，1e8 -> 1.0亿。
String formatCount(int n) {
  if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
  return n.toString();
}

/// 秒数 -> mm:ss（超过 1 小时 -> h:mm:ss）。
String formatDuration(int seconds) {
  if (seconds <= 0) return '--:--';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// 卡片右下角的半透明小角标（时长/清晰度之类）。
class CornerBadge extends StatelessWidget {
  const CornerBadge({super.key, required this.text, this.right = 6, this.bottom = 6});

  final String text;
  final double right;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: right,
      bottom: bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.25,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// 圆角小胶囊（用于「竖屏」「UP」这类标签）。
class MiniChip extends StatelessWidget {
  const MiniChip({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? PiliColor.textSub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: c.withOpacity(0.5), width: 0.8),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontSize: 10, height: 1.2),
      ),
    );
  }
}
