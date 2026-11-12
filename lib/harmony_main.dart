import 'package:flutter/material.dart';

/// PiliPlus 鸿蒙原生构建的最小入口。
///
/// 说明：当前 HAP 为可安装骨架。主工程 (lib/) 的 B 站业务依赖大量尚未
/// 鸿蒙化的原生插件（播放器 media_kit / 弹幕 / 投屏 / WebView 等），
/// 需要在 CPF-Flutter 生态补齐对应 ohos 实现后逐步迁入，见 README。
void main() => runApp(const PiliPlusHarmonyApp());

class PiliPlusHarmonyApp extends StatelessWidget {
  const PiliPlusHarmonyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PiliPlus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFB7299)),
        useMaterial3: true,
      ),
      home: const HarmonyHomePage(),
    );
  }
}

class HarmonyHomePage extends StatelessWidget {
  const HarmonyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PiliPlus · HarmonyOS')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_display_outlined, size: 64, color: Color(0xFFFB7299)),
              SizedBox(height: 16),
              Text('HarmonyOS 原生包', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                '当前为可安装骨架。B 站业务功能待原生插件鸿蒙化后迁入。',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
