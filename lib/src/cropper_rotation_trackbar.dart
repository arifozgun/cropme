import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cropper_theme.dart';

/// Apple-style minimal rotation trackbar for image cropping.
///
/// Features:
/// - Simple tick marks with gradient opacity (darker at center, lighter at edges)
/// - Accent-colored center indicator
/// - Smooth spring physics for snap-back
/// - Haptic feedback at key angles
/// - Clean, minimal design without background or labels
class CropperRotationTrackbar extends StatefulWidget {
  /// Current rotation value in radians.
  final double rotation;

  /// Callback when rotation changes.
  final ValueChanged<double> onRotationChanged;

  /// Callback when user ends dragging (for spring animation).
  final ValueChanged<double>? onRotationEnd;

  /// Maximum rotation in degrees (both directions).
  final double maxRotationDegrees;

  /// Theme data for styling.
  final CropperThemeData theme;

  const CropperRotationTrackbar({
    super.key,
    required this.rotation,
    required this.onRotationChanged,
    this.onRotationEnd,
    this.maxRotationDegrees = 45.0,
    required this.theme,
  });

  @override
  State<CropperRotationTrackbar> createState() => _CropperRotationTrackbarState();
}

class _CropperRotationTrackbarState extends State<CropperRotationTrackbar>
    with SingleTickerProviderStateMixin {
  // For rubber band effect when dragging past limits
  static const double _rubberBandFactor = 0.3;

  // Haptic feedback angles (degrees)
  static const List<double> _hapticAngles = [0, -15, 15, -30, 30, -45, 45];

  double? _lastHapticAngle;
  bool _isDragging = false;

  // Spring physics for snap-back
  AnimationController? _snapController;

  double get _maxRadians => widget.maxRotationDegrees * math.pi / 180;

  @override
  void dispose() {
    _snapController?.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _isDragging = true;
    _snapController?.stop();
    _lastHapticAngle = null;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final dragDelta = details.delta.dx;
    const sensitivity = 0.005;

    double newRotation = widget.rotation - (dragDelta * sensitivity);

    // Apply rubber band effect if past limits
    if (newRotation.abs() > _maxRadians) {
      final overshoot = newRotation.abs() - _maxRadians;
      final rubberBanded = _maxRadians + (overshoot * _rubberBandFactor);
      newRotation = newRotation.sign * rubberBanded;
    }

    // Check for haptic feedback
    final newDegrees = newRotation * 180 / math.pi;
    for (final angle in _hapticAngles) {
      if (_lastHapticAngle != angle) {
        final prevDegrees = widget.rotation * 180 / math.pi;
        if ((prevDegrees < angle && newDegrees >= angle) ||
            (prevDegrees > angle && newDegrees <= angle) ||
            (prevDegrees - angle).abs() < 0.5) {
          _lastHapticAngle = angle;
          HapticFeedback.selectionClick();
          break;
        }
      }
    }

    widget.onRotationChanged(newRotation);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;

    double targetRotation = widget.rotation;
    if (widget.rotation.abs() > _maxRadians) {
      targetRotation = widget.rotation.sign * _maxRadians;
    }

    if (targetRotation.abs() < 0.02) {
      targetRotation = 0.0;
      HapticFeedback.lightImpact();
    }

    widget.onRotationEnd?.call(targetRotation);
  }

  void _onDoubleTap() {
    HapticFeedback.lightImpact();
    widget.onRotationEnd?.call(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onDoubleTap: _onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 40,
        child: CustomPaint(
          painter: _RotationTrackbarPainter(
            rotation: widget.rotation,
            maxRotation: _maxRadians,
            accentColor: widget.theme.accentColor,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Custom painter for the minimal rotation trackbar.
class _RotationTrackbarPainter extends CustomPainter {
  final double rotation;
  final double maxRotation;
  final Color accentColor;

  _RotationTrackbarPainter({
    required this.rotation,
    required this.maxRotation,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final rotationDegrees = rotation * 180 / math.pi;

    const tickSpacing = 8.0;
    const ticksPerSide = 25;

    final offset = -rotationDegrees * (tickSpacing / 5);

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;

    for (int i = -ticksPerSide; i <= ticksPerSide; i++) {
      final x = centerX + offset + (i * tickSpacing);

      if (x < 0 || x > size.width) continue;

      final isMajor = i % 3 == 0;
      final tickHeight = isMajor ? 20.0 : 14.0;

      tickPaint.color = Colors.grey.withValues(alpha: 0.5);
      tickPaint.strokeWidth = 1.5;

      canvas.drawLine(
        Offset(x, centerY - tickHeight / 2),
        Offset(x, centerY + tickHeight / 2),
        tickPaint,
      );
    }

    // Draw fixed center indicator on top
    final centerIndicatorPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(centerX, centerY - 14),
      Offset(centerX, centerY + 14),
      centerIndicatorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RotationTrackbarPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
