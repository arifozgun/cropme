import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'cropper_theme.dart';

/// Custom painter for the crop overlay.
///
/// Draws the border and rule-of-thirds grid lines inside the crop rect.
class CropperOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final CropperThemeData theme;

  CropperOverlayPainter({required this.cropRect, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    // Border Gradient
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = ui.Gradient.linear(cropRect.topLeft, cropRect.bottomRight, [
        Colors.transparent,
        Colors.transparent,
      ]);

    canvas.drawRSuperellipse(
      ui.RSuperellipse.fromRectAndRadius(cropRect, Radius.circular(theme.cropCornerRadius)),
      borderPaint,
    );

    // Grid Lines - Rule of thirds
    final gridPaint = Paint()
      ..color = theme.gridLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + cropRect.height / 3),
      Offset(cropRect.right, cropRect.top + cropRect.height / 3),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + 2 * cropRect.height / 3),
      Offset(cropRect.right, cropRect.top + 2 * cropRect.height / 3),
      gridPaint,
    );

    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + cropRect.width / 3, cropRect.top),
      Offset(cropRect.left + cropRect.width / 3, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + 2 * cropRect.width / 3, cropRect.top),
      Offset(cropRect.left + 2 * cropRect.width / 3, cropRect.bottom),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(CropperOverlayPainter oldDelegate) =>
      oldDelegate.cropRect != cropRect;
}
