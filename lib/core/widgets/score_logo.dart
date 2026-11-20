import 'package:flutter/material.dart';

/// Predefined size variants for the Score logo.
enum ScoreLogoSize {
  /// Small compact variant (width ~56.2, height 32.0).
  /// Ideal for compact placements, cards, dialogs, chips, and footers.
  small,

  /// Medium variant (width ~98.4, height 56.0).
  /// Standard consistent size for AppBars, headers, and navigation rows.
  medium,

  /// Large variant (width ~219.6, height 125.0).
  /// Standard hero size for Welcome and Login screens.
  large,

  /// Custom variant using caller-specified dimensions while preserving aspect ratio.
  custom,
}

/// A centralized reusable widget for rendering the Score logo consistently
/// across the entire application without distortion or sizing discrepancies.
class ScoreLogo extends StatelessWidget {
  /// Primary constructor allowing size variant or optional dimension overrides.
  const ScoreLogo({
    super.key,
    this.size = ScoreLogoSize.medium,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.opacity,
    this.semanticLabel = 'Score Logo',
  });

  /// Factory constructor for small/compact logo placement.
  const ScoreLogo.small({
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.opacity,
    this.semanticLabel = 'Score Logo',
  })  : size = ScoreLogoSize.small,
        width = null,
        height = null;

  /// Factory constructor for standard AppBar/header usage.
  const ScoreLogo.medium({
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.opacity,
    this.semanticLabel = 'Score Logo',
  })  : size = ScoreLogoSize.medium,
        width = null,
        height = null;

  /// Factory constructor for large hero/Welcome/Login screens.
  const ScoreLogo.large({
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.opacity,
    this.semanticLabel = 'Score Logo',
  })  : size = ScoreLogoSize.large,
        width = null,
        height = null;

  /// Factory constructor for custom sized layouts where required.
  const ScoreLogo.custom({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.opacity,
    this.semanticLabel = 'Score Logo',
  }) : size = ScoreLogoSize.custom;

  /// Size preset.
  final ScoreLogoSize size;

  /// Optional width override (dp).
  final double? width;

  /// Optional height override (dp).
  final double? height;

  /// Image scaling algorithm (defaults to BoxFit.contain).
  final BoxFit fit;

  /// Alignment within the container.
  final AlignmentGeometry alignment;

  /// Optional opacity (0.0 to 1.0).
  final double? opacity;

  /// Accessibility label.
  final String semanticLabel;

  /// Asset path for the blended Score logo.
  static const String assetPath = 'assets/images/app_logo_blended.png';

  /// Native aspect ratio (width / height = 390 / 222).
  static const double aspectRatio = 390.0 / 222.0;

  /// Default dimensions for predefined variants.
  static const Size smallDimensions =
      Size(32.0 * aspectRatio, 32.0); // ~56.2 x 32.0
  static const Size mediumDimensions =
      Size(56.0 * aspectRatio, 56.0); // ~98.4 x 56.0
  static const Size largeDimensions =
      Size(125.0 * aspectRatio, 125.0); // ~219.6 x 125.0

  /// Brand royal blue color used for fallback text.
  static const Color _brandRoyalBlue = Color(0xFF083FA5);

  /// Resolves effective target size based on variant and explicit dimensions.
  Size _resolveDimensions() {
    if (size == ScoreLogoSize.custom || width != null || height != null) {
      if (width != null && height != null) {
        return Size(width!, height!);
      } else if (height != null) {
        return Size(height! * aspectRatio, height!);
      } else if (width != null) {
        return Size(width!, width! / aspectRatio);
      }
    }

    switch (size) {
      case ScoreLogoSize.small:
        return smallDimensions;
      case ScoreLogoSize.medium:
        return mediumDimensions;
      case ScoreLogoSize.large:
        return largeDimensions;
      case ScoreLogoSize.custom:
        return mediumDimensions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetSize = _resolveDimensions();

    final logoImage = Image.asset(
      assetPath,
      width: targetSize.width,
      height: targetSize.height,
      fit: fit,
      alignment: alignment,
      opacity: opacity != null ? AlwaysStoppedAnimation(opacity!) : null,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) => _buildFallback(targetSize),
    );

    return SizedBox(
      width: targetSize.width,
      height: targetSize.height,
      child: logoImage,
    );
  }

  Widget _buildFallback(Size size) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'ScorE',
          style: TextStyle(
            fontSize: size.height * 0.5,
            fontWeight: FontWeight.w900,
            color: _brandRoyalBlue,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
