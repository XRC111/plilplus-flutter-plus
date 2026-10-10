import 'package:PiliPlus/models/common/enum_with_label.dart';

/// Which design language the app renders in.
///
/// The two styles coexist in the codebase: [material] is upstream PiliPlus,
/// [hyperOs] swaps the shell (top bar / bottom nav / dialogs) and common
/// controls for the `flutter_miuix` equivalents.
///
/// Stored as an index in [SettingBoxKey.uiStyle] so the list can grow later
/// without migrating existing preferences.
enum UiStyle with EnumWithLabel {
  /// Upstream PiliPlus look (Material 3).
  material,

  /// Xiaomi HyperOS look, via `flutter_miuix`.
  hyperOs;

  @override
  String get label => switch (this) {
    UiStyle.material => '原生 Material',
    UiStyle.hyperOs => 'HyperOS 风格',
  };

  static UiStyle fromIndex(int? index) {
    if (index == null || index < 0 || index >= values.length) {
      return UiStyle.material;
    }
    return values[index];
  }

  bool get isHyperOs => this == UiStyle.hyperOs;
}
