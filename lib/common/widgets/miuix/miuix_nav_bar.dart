import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the bottom navigation bar with `flutter_miuix` widgets.
///
/// Used instead of the Material bars when the UI style is HyperOS. It keeps the
/// same selection contract as the Material versions, so index management,
/// hide-on-scroll and badges in `MainController` stay untouched.
abstract final class MiuixNavBar {
  /// The regular (non-floating) bar.
  static Widget build({
    required List<NavigationBarType> items,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required Widget Function(NavigationBarType item, {bool selected})
    iconBuilder,
  }) {
    return MiuixNavigationBar(
      children: [
        for (var i = 0; i < items.length; i++)
          MiuixNavigationBarItem(
            selected: i == selectedIndex,
            onPressed: () => onSelected(i),
            icon: iconBuilder(items[i], selected: i == selectedIndex),
            label: items[i].label,
          ),
      ],
    );
  }

  /// The floating pill bar — the most recognisable HyperOS shape.
  static Widget buildFloating({
    required List<NavigationBarType> items,
    required int selectedIndex,
    required ValueChanged<int> onSelected,
    required Widget Function(NavigationBarType item, {bool selected})
    iconBuilder,
  }) {
    return MiuixFloatingNavigationBar(
      children: [
        for (var i = 0; i < items.length; i++)
          MiuixNavigationBarItem(
            selected: i == selectedIndex,
            onPressed: () => onSelected(i),
            icon: iconBuilder(items[i], selected: i == selectedIndex),
            label: items[i].label,
          ),
      ],
    );
  }
}
