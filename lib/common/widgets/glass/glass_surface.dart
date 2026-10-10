import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// A reusable liquid-glass surface for the PiliPlus navigation shell.
///
/// It wraps a child in a [LiquidGlassLens]:
///  - on **Impeller** (Android/iOS/macOS with the new renderer) the lens
///    refracts the *live* backdrop behind it — the body content scrolling
///    underneath the floating navigation bar, for example;
///  - on **Skia / Web** without a [LiquidGlassView] ancestor, the package
///    automatically degrades to a frosted look (blur + tint + lit rim) and
///    logs a one-time warning. That fallback is exactly what we want here,
///    so no extra plumbing is required for the build to stay green.
///
/// Keep [child] transparent (no opaque background) so the glass shows
/// through it.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.cornerRadius = 28.0,
    this.blurSigma = 3.0,
    this.tint,
    this.shape,
    this.refraction,
    this.visibility = true,
  });

  /// The widget drawn *inside* the glass (the nav bar buttons, dialog
  /// content, …). Should have no opaque background of its own.
  final Widget child;

  /// Corner radius of the capsule / rounded surface, in logical pixels.
  final double cornerRadius;

  /// Frost/refraction blur strength (sigma for both axes).
  final double blurSigma;

  /// Optional tint over the glass. Defaults to a light/white or dark
  /// translucent fill depending on the current brightness.
  final Color? tint;

  /// Optional explicit shape; defaults to a continuous (Apple-capsule)
  /// rounded rectangle.
  final LiquidGlassShape? shape;

  /// Optional refraction tuning; defaults to a gentle bend.
  final LiquidGlassRefraction? refraction;

  /// When `false`, the glass and its child are removed (no backdrop cost).
  final bool visibility;

  Color _defaultTint(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? const Color(0x24FFFFFF)
        : const Color(0x40FFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassShape resolvedShape = shape ??
        LiquidGlassShape.continuousRoundedRectangle(
          cornerRadius: cornerRadius,
          borderWidth: 1.2,
        );

    final style = LiquidGlassStyle(
      shape: resolvedShape,
      appearance: LiquidGlassAppearance(
        blur: LiquidGlassBlur(sigmaX: blurSigma, sigmaY: blurSigma),
        color: tint ?? _defaultTint(context),
      ),
      refraction: refraction ?? const LiquidGlassRefraction(distortion: 0.04),
    );

    return LiquidGlassLens(
      style: style,
      visibility: visibility,
      child: child,
    );
  }
}
