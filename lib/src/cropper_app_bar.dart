import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:transparent_tap_animation/transparent_tap_animation.dart';
import 'cropper_glass_button.dart';
import 'cropper_theme.dart';

/// Top app bar for the image cropper.
///
/// Contains a back button (close) and a reset button.
class CropperAppBar extends StatelessWidget {
  final VoidCallback onReset;
  final CropperThemeData theme;

  const CropperAppBar({super.key, required this.onReset, required this.theme});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            TransparentTapAnimation(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  theme.closeIcon,
                  color: theme.appBarForegroundColor,
                  size: 24,
                ),
              ),
            ),
            const Spacer(),
            CropperGlassButton(
              text: theme.resetLabel,
              onTap: onReset,
              isSmall: true,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}
