import 'package:flutter/material.dart';
import 'package:transparent_tap_animation/transparent_tap_animation.dart';
import 'cropper_theme.dart';

/// Glass-effect button used in the cropper AppBar.
///
/// Features a gradient border with translucent background.
class CropperGlassButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isSmall;
  final CropperThemeData theme;

  const CropperGlassButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isSmall = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return TransparentTapAnimation(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 16,
          vertical: 8,
        ),
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          color: theme.buttonBackgroundColor,
        ),
        child: Text(text, style: theme.buttonTextStyle),
      ),
    );
  }
}
