<div align="center">

<img width="160" src="assets/images/logo/logo.png" alt="PiliPlus" />

# PiliPlus · Liquid Glass

**A Liquid Glass fork of the PiliPlus Bilibili client, built with Flutter**

[中文](README.md) | English

[![Build Android APK](https://github.com/XRC111/plilplus-flutter-plus/actions/workflows/build_android.yml/badge.svg)](https://github.com/XRC111/plilplus-flutter-plus/actions/workflows/build_android.yml)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue?style=flat-square)](./LICENSE)

</div>

---

> [!NOTE]
> This is a **Liquid Glass** fork of [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus), based on upstream `2.1.6`.
> Everything except the shell styling below is identical to upstream.

## What changed

The navigation shell is wrapped with shader-based liquid glass using [`liquid_glass_easy`](https://pub.dev/packages/liquid_glass_easy):

| Area | Change |
| --- | --- |
| Floating bottom bar | Glass capsule that **refracts** scrolling content behind it |
| Regular bottom bar | Both `MYBar` and classic `BottomNavigationBar` are glass-styled |
| Navigation drawer | Tablet drawer uses the same glass surface |
| Dialogs | Confirmation and follow-status dialogs use frosted glass panels |

On Impeller (default on Android / iOS) the glass refracts real content; on Skia / Web it degrades to frosted glass (blur + tint + rim highlight) without errors.

> Refraction only happens in **floating bottom bar** mode, because only then is there content behind the bar.

### Touched files

```
pubspec.yaml                                     # liquid_glass_easy dependency
lib/common/widgets/glass/glass_surface.dart      # reusable GlassSurface widget
lib/common/widgets/floating_navigation_bar.dart  # floating bar
lib/common/widgets/dialog/dialog.dart            # dialogs
lib/pages/main/view.dart                         # regular bar / drawer
.github/workflows/build_android.yml              # APK build
```

## Build

This project requires a **patched Flutter SDK** — upstream exposes private framework APIs via `lib/scripts/patch.ps1`.

```bash
fvm install                                   # Flutter 3.47.6
pwsh lib/scripts/patch.ps1 android            # required, then re-run pub get
flutter build apk --release --split-per-abi
```

CI ([build_android.yml](.github/workflows/build_android.yml)) builds the APK on every push.

## Download

Grab the APK from [Actions](https://github.com/XRC111/plilplus-flutter-plus/actions/workflows/build_android.yml), or build locally.

## Platforms

Android · iOS · iPad · Windows · Linux

## Disclaimer

For personal learning and testing only. Please delete within 24 hours of download. All APIs are collected from official sources; no cracking content is provided.

Credits: [guozhigq/pilipala](https://github.com/guozhigq/pilipala), [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX), [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus).

## License

GPL-3.0
