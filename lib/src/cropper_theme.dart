import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Theme configuration for the image cropper.
///
/// Provides colors, text styles, and labels that the cropper widgets use.
/// All properties have sensible defaults for a dark-themed cropper experience.
///
/// Pass this to [ImageCropper] via the `theme` parameter, or let it
/// fall back to automatic dark defaults.
class CropperThemeData {
  /// Background color of the cropper scaffold.
  final Color backgroundColor;

  /// Color used for overlaying the area outside the crop rect.
  final Color overlayColor;

  /// Blur sigma for the overlay outside the crop area.
  /// Set to 0 to disable blur. Defaults to 20.
  final double overlayBlurSigma;

  /// Platforms where overlay blur is enabled.
  /// Defaults to iOS and macOS. Web is always excluded.
  final Set<TargetPlatform> blurEnabledPlatforms;

  /// Color for the rule-of-thirds grid lines.
  final Color gridLineColor;

  /// Primary accent color (used by rotation indicator, highlights).
  final Color accentColor;

  /// Background color for buttons (e.g. the glass button).
  final Color buttonBackgroundColor;

  /// Text color for buttons.
  final Color buttonTextColor;

  /// Text style for button labels.
  final TextStyle buttonTextStyle;

  /// Icon/text color for app bar elements.
  final Color appBarForegroundColor;

  /// Icon for the close/back button in the app bar.
  final IconData closeIcon;

  /// Color for the loading indicator.
  final Color loadingIndicatorColor;

  /// Background (track) color for the circular progress indicator.
  final Color progressIndicatorBackgroundColor;

  /// Background color for the crop button.
  final Color cropButtonColor;

  /// Text/icon color for the crop button.
  final Color cropButtonTextColor;

  /// Label for the "Reset" button in the app bar.
  final String resetLabel;

  /// Label for the "Crop & Save" button.
  final String cropLabel;

  /// Corner radius for the crop rect overlay.
  final double cropCornerRadius;

  const CropperThemeData({
    this.backgroundColor = const Color(0xFF000000),
    this.overlayColor = const Color(0x99000000),
    this.overlayBlurSigma = 20.0,
    this.blurEnabledPlatforms = const {TargetPlatform.iOS, TargetPlatform.macOS},
    this.gridLineColor = const Color(0x33FFFFFF),
    this.accentColor = const Color(0xFFFFC107),
    this.buttonBackgroundColor = const Color(0xFF2C2C2E),
    this.buttonTextColor = const Color(0xFFFFFFFF),
    this.buttonTextStyle = const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Color(0xFFFFFFFF),
    ),
    this.appBarForegroundColor = const Color(0xFFFFFFFF),
    this.closeIcon = CupertinoIcons.xmark,
    this.loadingIndicatorColor = const Color(0xFFFFFFFF),
    this.progressIndicatorBackgroundColor = const Color(0xFF000000),
    this.cropButtonColor = const Color(0xFFFFFFFF),
    this.cropButtonTextColor = const Color(0xFF000000),
    this.resetLabel = 'Reset',
    this.cropLabel = 'Crop & Save',
    this.cropCornerRadius = 12.0,
  });

  /// Creates a copy with optional overrides.
  CropperThemeData copyWith({
    Color? backgroundColor,
    Color? overlayColor,
    double? overlayBlurSigma,
    Set<TargetPlatform>? blurEnabledPlatforms,
    Color? gridLineColor,
    Color? accentColor,
    Color? buttonBackgroundColor,
    Color? buttonTextColor,
    TextStyle? buttonTextStyle,
    Color? appBarForegroundColor,
    IconData? closeIcon,
    Color? loadingIndicatorColor,
    Color? progressIndicatorBackgroundColor,
    Color? cropButtonColor,
    Color? cropButtonTextColor,
    String? resetLabel,
    String? cropLabel,
    double? cropCornerRadius,
  }) {
    return CropperThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      overlayColor: overlayColor ?? this.overlayColor,
      overlayBlurSigma: overlayBlurSigma ?? this.overlayBlurSigma,
      blurEnabledPlatforms: blurEnabledPlatforms ?? this.blurEnabledPlatforms,
      gridLineColor: gridLineColor ?? this.gridLineColor,
      accentColor: accentColor ?? this.accentColor,
      buttonBackgroundColor: buttonBackgroundColor ?? this.buttonBackgroundColor,
      buttonTextColor: buttonTextColor ?? this.buttonTextColor,
      buttonTextStyle: buttonTextStyle ?? this.buttonTextStyle,
      appBarForegroundColor: appBarForegroundColor ?? this.appBarForegroundColor,
      closeIcon: closeIcon ?? this.closeIcon,
      loadingIndicatorColor: loadingIndicatorColor ?? this.loadingIndicatorColor,
      progressIndicatorBackgroundColor: progressIndicatorBackgroundColor ?? this.progressIndicatorBackgroundColor,
      cropButtonColor: cropButtonColor ?? this.cropButtonColor,
      cropButtonTextColor: cropButtonTextColor ?? this.cropButtonTextColor,
      resetLabel: resetLabel ?? this.resetLabel,
      cropLabel: cropLabel ?? this.cropLabel,
      cropCornerRadius: cropCornerRadius ?? this.cropCornerRadius,
    );
  }
}
