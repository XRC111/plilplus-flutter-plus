import 'package:PiliPlus/utils/font_utils.dart';
import 'package:flutter_miuix/miuix.dart' show MiuixSquircleBorder;
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:material_ui/material_ui.dart';

/// Theme-level overrides that give the app a HyperOS (flutter_miuix) look
/// without touching any page widget.
///
/// This is the "style switch" half of the two-mode UI: the shapes, colours
/// and control styling change, while the pages keep their upstream layout.
/// See [Pref.uiStyle] / `UiStyle.hyperOs`.
abstract final class HyperOsTheme {
  /// HyperOS uses noticeably rounder geometry than Material 3 defaults.
  /// These are applied over the upstream [ThemeData] so every Material widget
  /// that reads from the theme picks them up automatically.
  static ThemeData apply(ThemeData base, {required bool isDark}) {
    final scheme = base.colorScheme;
    final fontFamily = FontUtils.fontFamily;
    final fontWeight = Pref.appFontWeight;

    // Miuix surfaces are flatter and less saturated than M3's tonal palette:
    // cards sit on the background with almost no tint, and the primary is
    // reserved for interactive elements.
    final surface = isDark
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerLowest;
    final cardColor = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLow;

    return base.copyWith(
      // ── shape ────────────────────────────────────────────────
      // Larger, more continuous radii are the most recognisable part of the
      // HyperOS look, and they are cheap to apply globally.
      cardTheme: base.cardTheme.copyWith(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const MiuixSquircleBorder(cornerRadius: 16),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        elevation: 0,
        shape: const MiuixSquircleBorder(cornerRadius: 28),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: surface,
        elevation: 0,
        modalElevation: 0,
        shape: const MiuixSquircleBorder(cornerRadius: 28),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: surface,
        elevation: 0,
        shape: const MiuixSquircleBorder(cornerRadius: 16),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorShape: const StadiumBorder(),
      ),
      // ── controls ─────────────────────────────────────────────
      // Squarer, flatter buttons with a subtle radius, matching miuix.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _kRadius12All),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: _kRadius12All),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _kRadius12All),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _kRadius12All),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerLow,
        border: const OutlineInputBorder(
          borderRadius: _kRadius12All,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: _kRadius12All,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _kRadius12All,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        shape: const RoundedRectangleBorder(borderRadius: _kRadius12All),
        minVerticalPadding: 10,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        elevation: 0,
      ),
      dividerTheme: base.dividerTheme.copyWith(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 0.5,
        space: 0.5,
      ),
      // ── motion ───────────────────────────────────────────────
      // miuix transitions are quicker and less bouncy than M3's default zoom.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      textTheme: fontWeight == FontWeight.normal
          ? base.textTheme
          : base.textTheme.apply(fontFamily: fontFamily),
    );
  }

  static const _kRadius12All = BorderRadius.all(Radius.circular(12));
}