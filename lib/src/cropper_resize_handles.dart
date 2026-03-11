import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enum to represent which edge/corner is being dragged.
enum CropHandle { none, topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right }

/// Interactive resize handles for the crop rect.
///
/// Allows free-form cropping by dragging edges and corners.
class CropperResizeHandles extends StatefulWidget {
  final Rect cropRect;
  final void Function(Rect, CropHandle) onCropRectChanged;
  final VoidCallback? onResizeStart;
  final VoidCallback? onResizeEnd;
  final double minSize;
  final Size containerSize;

  const CropperResizeHandles({
    super.key,
    required this.cropRect,
    required this.onCropRectChanged,
    this.onResizeStart,
    this.onResizeEnd,
    this.minSize = 80.0,
    required this.containerSize,
  });

  @override
  State<CropperResizeHandles> createState() => _CropperResizeHandlesState();
}

class _CropperResizeHandlesState extends State<CropperResizeHandles> {
  CropHandle _activeHandle = CropHandle.none;
  Offset _dragStart = Offset.zero;
  Rect _initialCropRect = Rect.zero;

  // Handle hit area size (larger than visual for easier touch)
  static const double handleHitSize = 60.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Edge handles FIRST (so corners are on top for priority)
        _buildEdgeHandle(CropHandle.top),
        _buildEdgeHandle(CropHandle.bottom),
        _buildEdgeHandle(CropHandle.left),
        _buildEdgeHandle(CropHandle.right),

        // Corner handles LAST (on top)
        _buildCornerHandle(CropHandle.topLeft),
        _buildCornerHandle(CropHandle.topRight),
        _buildCornerHandle(CropHandle.bottomLeft),
        _buildCornerHandle(CropHandle.bottomRight),
      ],
    );
  }

  Widget _buildCornerHandle(CropHandle handle) {
    final position = _getHandlePosition(handle);

    return Positioned(
      left: position.dx - handleHitSize / 2,
      top: position.dy - handleHitSize / 2,
      width: handleHitSize,
      height: handleHitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _onDragStart(handle, details.globalPosition),
        onPanUpdate: (details) => _onDragUpdate(details.globalPosition),
        onPanEnd: (_) => _onDragEnd(),
      ),
    );
  }

  Widget _buildEdgeHandle(CropHandle handle) {
    final position = _getHandlePosition(handle);
    final isHorizontal = handle == CropHandle.top || handle == CropHandle.bottom;

    final double width = isHorizontal ? widget.cropRect.width * 0.8 : handleHitSize;
    final double height = isHorizontal ? handleHitSize : widget.cropRect.height * 0.8;

    return Positioned(
      left: position.dx - width / 2,
      top: position.dy - height / 2,
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) => _onDragStart(handle, details.globalPosition),
        onPanUpdate: (details) => _onDragUpdate(details.globalPosition),
        onPanEnd: (_) => _onDragEnd(),
      ),
    );
  }

  Offset _getHandlePosition(CropHandle handle) {
    final rect = widget.cropRect;

    return switch (handle) {
      CropHandle.topLeft => rect.topLeft,
      CropHandle.topRight => rect.topRight,
      CropHandle.bottomLeft => rect.bottomLeft,
      CropHandle.bottomRight => rect.bottomRight,
      CropHandle.top => Offset(rect.center.dx, rect.top),
      CropHandle.bottom => Offset(rect.center.dx, rect.bottom),
      CropHandle.left => Offset(rect.left, rect.center.dy),
      CropHandle.right => Offset(rect.right, rect.center.dy),
      CropHandle.none => Offset.zero,
    };
  }

  void _onDragStart(CropHandle handle, Offset globalPosition) {
    HapticFeedback.lightImpact();
    setState(() {
      _activeHandle = handle;
      _dragStart = globalPosition;
      _initialCropRect = widget.cropRect;
    });
    widget.onResizeStart?.call();
  }

  void _onDragUpdate(Offset globalPosition) {
    if (_activeHandle == CropHandle.none) return;

    final delta = globalPosition - _dragStart;
    Rect newRect = _calculateNewRect(delta);

    // Apply primary sizing constraints (min size)
    newRect = _enforceMinSize(newRect);

    // Add rubber-band visual effect when reaching screen edges
    newRect = _applyResistanceToRect(newRect);

    if (newRect != widget.cropRect) {
      widget.onCropRectChanged(newRect, _activeHandle);
    }
  }

  Rect _enforceMinSize(Rect rect) {
    double left = rect.left;
    double top = rect.top;
    double right = rect.right;
    double bottom = rect.bottom;

    if (right - left < widget.minSize) {
      if (_activeHandle == CropHandle.left ||
          _activeHandle == CropHandle.topLeft ||
          _activeHandle == CropHandle.bottomLeft) {
        left = right - widget.minSize;
      } else {
        right = left + widget.minSize;
      }
    }

    if (bottom - top < widget.minSize) {
      if (_activeHandle == CropHandle.top ||
          _activeHandle == CropHandle.topLeft ||
          _activeHandle == CropHandle.topRight) {
        top = bottom - widget.minSize;
      } else {
        bottom = top + widget.minSize;
      }
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Applies rubber-band resistance when dragging handles towards/past screen boundaries.
  Rect _applyResistanceToRect(Rect rect) {
    double left = rect.left;
    double top = rect.top;
    double right = rect.right;
    double bottom = rect.bottom;

    const topPadding = 100.0;
    const bottomPadding = 210.0;
    const horizontalPadding = 15.0;

    final maxRight = widget.containerSize.width - horizontalPadding;
    final maxBottom = widget.containerSize.height - bottomPadding;

    const resistance = 0.4;

    if (left < horizontalPadding) {
      left = horizontalPadding - (horizontalPadding - left) * resistance;
    }
    if (top < topPadding) {
      top = topPadding - (topPadding - top) * resistance;
    }
    if (right > maxRight) {
      right = maxRight + (right - maxRight) * resistance;
    }
    if (bottom > maxBottom) {
      bottom = maxBottom + (bottom - maxBottom) * resistance;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect _calculateNewRect(Offset delta) {
    final rect = _initialCropRect;

    return switch (_activeHandle) {
      CropHandle.topLeft => Rect.fromLTRB(
        rect.left + delta.dx,
        rect.top + delta.dy,
        rect.right,
        rect.bottom,
      ),
      CropHandle.topRight => Rect.fromLTRB(
        rect.left,
        rect.top + delta.dy,
        rect.right + delta.dx,
        rect.bottom,
      ),
      CropHandle.bottomLeft => Rect.fromLTRB(
        rect.left + delta.dx,
        rect.top,
        rect.right,
        rect.bottom + delta.dy,
      ),
      CropHandle.bottomRight => Rect.fromLTRB(
        rect.left,
        rect.top,
        rect.right + delta.dx,
        rect.bottom + delta.dy,
      ),
      CropHandle.top => Rect.fromLTRB(rect.left, rect.top + delta.dy, rect.right, rect.bottom),
      CropHandle.bottom => Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom + delta.dy),
      CropHandle.left => Rect.fromLTRB(rect.left + delta.dx, rect.top, rect.right, rect.bottom),
      CropHandle.right => Rect.fromLTRB(rect.left, rect.top, rect.right + delta.dx, rect.bottom),
      CropHandle.none => rect,
    };
  }

  void _onDragEnd() {
    HapticFeedback.lightImpact();
    setState(() {
      _activeHandle = CropHandle.none;
    });
    widget.onResizeEnd?.call();
  }
}
