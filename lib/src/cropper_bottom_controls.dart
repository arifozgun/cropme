import 'package:flutter/material.dart';
import 'package:transparent_tap_animation/transparent_tap_animation.dart';
import 'cropper_rotation_trackbar.dart';
import 'cropper_theme.dart';

/// Bottom control panel for the image cropper.
///
/// Contains rotation trackbar and action buttons.
class CropperBottomControls extends StatelessWidget {
  final double rotation;
  final ValueChanged<double> onRotationChanged;
  final ValueChanged<double>? onRotationEnd;
  final VoidCallback onZoomIn;
  final VoidCallback onCrop;
  final bool isCropping;
  final CropperThemeData theme;

  const CropperBottomControls({
    super.key,
    required this.rotation,
    required this.onRotationChanged,
    this.onRotationEnd,
    required this.onZoomIn,
    required this.onCrop,
    this.isCropping = false,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          // Rotation trackbar container
          Container(
            margin: const EdgeInsets.only(
              top: 30,
              right: 15,
              left: 15,
              bottom: 20,
            ),
            decoration: ShapeDecoration(
              color: theme.buttonBackgroundColor,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(34),
              ),
            ),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(34),
              child: CropperRotationTrackbar(
                rotation: rotation,
                onRotationChanged: onRotationChanged,
                onRotationEnd: onRotationEnd,
                theme: theme,
              ),
            ),
          ),

          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TransparentTapAnimation(
              onTap: isCropping ? null : onCrop,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: ShapeDecoration(
                  color: theme.cropButtonColor,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                alignment: Alignment.center,
                child: isCropping
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                          backgroundColor:
                              theme.progressIndicatorBackgroundColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.loadingIndicatorColor,
                          ),
                        ),
                      )
                    : Text(
                        theme.cropLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.cropButtonTextColor,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
