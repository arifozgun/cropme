import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Custom clipper that clips everything EXCEPT the crop area.
///
/// This allows a blur or dark overlay to only affect the area
/// outside the crop rectangle.
class CropperInvertedClipper extends CustomClipper<Path> {
  final Rect cropRect;
  final double cornerRadius;

  CropperInvertedClipper({required this.cropRect, this.cornerRadius = 12.0});

  @override
  Path getClip(Size size) {
    // Create a path that covers the full screen
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    // Create a path for the crop area with rounded corners
    final cropPath = Path()
      ..addRSuperellipse(
        ui.RSuperellipse.fromRectAndRadius(
          cropRect,
          Radius.circular(cornerRadius),
        ),
      );
    // Subtract the crop area from the full screen
    return Path.combine(PathOperation.difference, backgroundPath, cropPath);
  }

  @override
  bool shouldReclip(CropperInvertedClipper oldClipper) =>
      oldClipper.cropRect != cropRect ||
      oldClipper.cornerRadius != cornerRadius;
}
