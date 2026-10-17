import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';

/// Maps PiliPlus navigation destinations onto the HyperOS icon set.
///
/// Only used when the UI style is HyperOS — the Material style keeps its own
/// icons. The miuix symbol set has no user/account glyph, so "我的" falls back
/// to the closest available idiom (contacts). The mapping is explicit rather
/// than automatic so a wrong guess is obvious here, not spread across the app.
abstract final class MiuixIconsMap {
  static Widget forNavBar(NavigationBarType type, {bool selected = false}) {
    final name = switch (type) {
      NavigationBarType.home => 'home',
      // 动态: no feed/motion glyph in the set; messages is the closest.
      NavigationBarType.dynamics => 'messages',
      // 我的: no account glyph; contacts is the nearest idiom.
      NavigationBarType.mine => 'contacts',
    };
    final vector = MiuixIcons.extended.byName(name);
    if (vector == null) {
      // Never ship a blank tab: fall back to the upstream icon.
      return Icon(type.icon.icon);
    }
    return MiuixIcon(
      vector: vector,
      size: 26,
      tint: null, // let the nav bar drive the state colour
    );
  }
}
