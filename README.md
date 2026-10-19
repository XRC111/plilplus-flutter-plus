<div align="center">

<img width="160" src="assets/images/logo/logo.png" alt="PiliPlus" />

# PiliPlus · Liquid Glass

**哔哩哔哩第三方客户端（Flutter）的 iOS 26 液态玻璃改造分支**

中文 | [English](README.en.md)

[![Build Android APK](https://github.com/XRC111/plilplus-flutter-plus/actions/workflows/build_android.yml/badge.svg)](https://github.com/XRC111/plilplus-flutter-plus/actions/workflows/build_android.yml)
[![Stars](https://img.shields.io/github/stars/XRC111/plilplus-flutter-plus?style=flat-square)](https://github.com/XRC111/plilplus-flutter-plus/stargazers)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square)](./LICENSE)

<img src="assets/screenshots/510shots_so.png" width="24%" />
<img src="assets/screenshots/174shots_so.png" width="24%" />
<img src="assets/screenshots/850shots_so.png" width="24%" />
<img src="assets/screenshots/main_screen.png" width="96%" />

</div>

---

> [!NOTE]
> 这是 [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 的**液态玻璃（Liquid Glass）改造分支**，基于上游 `2.1.6`。除下述改动外，功能与上游一致。
>
> 上游仓库：<https://github.com/bggRGjQaUbCoE/PiliPlus>

## 这个分支改了什么

用 [`liquid_glass_easy`](https://pub.dev/packages/liquid_glass_easy) 给导航外壳套上基于着色器的液态玻璃：

| 部分 | 说明 |
| --- | --- |
| 悬浮底栏 | 玻璃胶囊，**实时折射**背后滚动的内容（需开启「悬浮底栏」设置） |
| 常规底栏 | `MYBar` 与经典 `BottomNavigationBar` 两种模式均已套用 |
| 侧边栏 | 平板模式下的 `NavigationDrawer` 已套用 |
| 对话框 | 确认框、追番状态选择框改为磨砂玻璃面板 |

**渲染表现**：Impeller（Android / iOS 默认）上玻璃实时折射背景；Skia / Web 自动降级为磨砂玻璃（模糊 + 着色 + 边缘高光），不会报错。

> 玻璃效果**只在「悬浮底栏」模式下才有折射**——只有它悬浮在内容之上，背后有内容可折射。常规底栏是不透明表面，视觉上是磨砂玻璃。

### 改动文件

```
pubspec.yaml                                     # 新增 liquid_glass_easy 依赖
lib/common/widgets/glass/glass_surface.dart      # 可复用玻璃组件 GlassSurface
lib/common/widgets/floating_navigation_bar.dart  # 悬浮底栏玻璃化
lib/common/widgets/dialog/dialog.dart            # 对话框玻璃化
lib/pages/main/view.dart                         # 常规底栏 / 侧边栏玻璃化
.github/workflows/build_android.yml              # Android APK 构建流程
```

## 构建

本项目**依赖打过补丁的 Flutter SDK**（上游通过 `lib/scripts/patch.ps1` 暴露若干框架私有 API），直接构建会报错，必须先应用补丁。

```bash
# 1. 安装与 pubspec.yaml 一致的 Flutter 版本（3.47.6）
fvm install

# 2. 应用 SDK 补丁（必须，之后要重跑 pub get）
pwsh lib/scripts/patch.ps1 android

# 3. 构建
flutter build apk --release --split-per-abi
```

GitHub Actions 已配置完整流程（[build_android.yml](.github/workflows/build_android.yml)），推送代码自动构建并上传 APK。

## 下载

- 从 [Actions](https://github.com/XRC111/plilplus-flutter-plus/actions/workflows/build_android.yml) 下载自动构建的 APK
- 或克隆仓库后本地编译

## 适配平台

- [x] Android
- [x] iOS
- [x] Pad
- [x] Windows
- [x] Linux

## 功能

完整功能清单（沿用上游，已折叠）：

<details>
<summary>展开查看全部功能</summary>

**内容浏览**

- [x] 推荐视频列表（App 端）、最热视频、热门直播、番剧列表
- [x] 屏蔽黑名单用户视频、无痕模式、游客模式
- [x] 搜索：热搜、历史、默认搜索词、投稿/番剧/直播/用户搜索、排序与时长筛选

**用户与社交**

- [x] 用户主页、关注/取关、粉丝与拉黑列表
- [x] 离线缓存、稍后再看、观看记录、我的收藏
- [x] 站内私信：发图、删除/置顶/撤回、举报
- [x] 动态：分类查看、评论与回复、转发、话题、图文
- [x] 多账号支持、WebDAV 备份/恢复

**视频播放**

- [x] 双击快进/暂停、垂直调亮度/音量、水平手势快进
- [x] 倍速、长按 2 倍速、画质/音质/解码选择、记忆播放
- [x] 弹幕（含高级弹幕、合并弹幕、彩色弹幕）、字幕、投屏（DLNA）
- [x] 超分辨率、Live Photo、视频截取动图、跳过片头片尾
- [x] 互动视频、播放课堂视频、AI 原声翻译

**评论与动态**

- [x] 楼中楼查看/定位/排序、点踩、带图评论、笔记
- [x] 编辑动态、发布/删除/置顶动态、富文本编辑与 @ 用户
- [x] 三连动画、投币动画、SponsorBlock

**其他**

- [x] 收藏夹/稍后再看的多选、复制、移动、排序
- [x] 创建/编辑/删除收藏夹、关注分组、修改个人资料
- [x] Cookie 登录、Win/Mac 极验与短信登录
- [x] WebDAV 备份、设置项齐全（画质/主题/震动/高帧率/横屏）

</details>

## 声明

本项目为个人兴趣开发，仅用于学习和测试，请于下载后 24 小时内删除。所用 API 均从官方网站收集，不提供任何破解内容。

致敬原作者：[guozhigq/pilipala](https://github.com/guozhigq/pilipala)、[orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)、[bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)。

## 致谢

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [media-kit](https://github.com/media-kit/media-kit)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [dio](https://pub.dev/packages/dio)
- [liquid_glass_easy](https://pub.dev/packages/liquid_glass_easy)

## Star History

<a href="https://star-history.dera.page/#XRC111/plilplus-flutter-plus&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://star-history.dera.page/svg?repos=XRC111/plilplus-flutter-plus&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://star-history.dera.page/svg?repos=XRC111/plilplus-flutter-plus&type=Date" />
   <img alt="Star History Chart" src="https://star-history.dera.page/svg?repos=XRC111/plilplus-flutter-plus&type=Date" />
 </picture>
</a>
