import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'cropper_overlay_painter.dart';
import 'cropper_inverted_clipper.dart';
import 'cropper_app_bar.dart';
import 'cropper_bottom_controls.dart';
import 'cropper_resize_handles.dart';
import 'crop_settings.dart';
import 'cropper_theme.dart';

// Apple-style spring parameters (matching UIKit spring animations)
// These create the natural, satisfying bounce characteristic of Apple's Photos app

// Primary spring - snappy response with controlled bounce
const SpringDescription _kAppleSpringDescription = SpringDescription(
  mass: 1.0,
  stiffness: 400.0,
  damping: 30.0,
);

// Bounce-back spring - softer for rubber-band snap-back effect
const SpringDescription _kBounceBackSpring = SpringDescription(
  mass: 1.6,
  stiffness: 110.0,
  damping: 30.0,
);

// Light spring for subtle transitions (like rotation)
const SpringDescription _kLightSpringDescription = SpringDescription(
  mass: 1.0,
  stiffness: 350.0,
  damping: 26.0,
);

// Centering spring - used for shifting crop rect to center
const SpringDescription _kCenteringSpring = SpringDescription(
  mass: 1.2,
  stiffness: 220.0,
  damping: 32.0,
);

// Rubber band resistance factor
const double _kRubberBandFactor = 0.35;

// Rotation sensitivity
const double _kRotationSensitivity = 0.6;

// Minimum velocity threshold for momentum animations
const double _kMinVelocityThreshold = 50.0;

/// Calculate the minimum scale required to cover the crop rect when image is rotated.
double _calculateMinScaleForRotation({
  required double imageWidth,
  required double imageHeight,
  required double cropWidth,
  required double cropHeight,
  required double rotation,
}) {
  final absRotation = rotation.abs();

  if (absRotation < 0.001) {
    final baseScaleX = cropWidth / imageWidth;
    final baseScaleY = cropHeight / imageHeight;
    return math.max(baseScaleX, baseScaleY);
  }

  final sinR = math.sin(absRotation).abs();
  final cosR = math.cos(absRotation).abs();

  final scaleForWidth = (cropWidth * cosR + cropHeight * sinR) / imageWidth;
  final scaleForHeight = (cropWidth * sinR + cropHeight * cosR) / imageHeight;

  final requiredScale = math.max(scaleForWidth, scaleForHeight);

  return requiredScale * 1.005;
}

/// An Apple Photos-style image cropper widget with spring physics,
/// rotation trackbar, free-form resize handles, and rubber-band snap-back.
///
/// Use [ImageCropper.show] to present the cropper as a full-screen dialog.
/// Returns a [CropResult] containing the cropped file and settings used.
class ImageCropper extends StatefulWidget {
  /// The source image bytes to crop.
  final Uint8List imageBytes;

  /// Optional initial settings to restore previous crop state.
  final CropSettings? initialSettings;

  /// Theme configuration. Uses dark defaults if not provided.
  final CropperThemeData theme;

  const ImageCropper({
    super.key,
    required this.imageBytes,
    this.initialSettings,
    this.theme = const CropperThemeData(),
  });

  /// Static method to show the cropper as a full-screen dialog.
  ///
  /// Returns [CropResult] containing the cropped file and settings used,
  /// or `null` if the user closed the cropper without cropping.
  static Future<CropResult?> show({
    required BuildContext context,
    required Uint8List imageBytes,
    CropSettings? initialSettings,
    CropperThemeData theme = const CropperThemeData(),
  }) async {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageCropper(
          imageBytes: imageBytes,
          initialSettings: initialSettings,
          theme: theme,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<ImageCropper> createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper>
    with TickerProviderStateMixin {
  ui.Image? _image;
  bool _isLoading = true;
  bool _isCropping = false;

  // Transform state
  final TransformationController _transformationController =
      TransformationController();

  // Animation controller for smooth transitions
  late AnimationController _transitionController;
  late Animation<double> _transitionAnimation;
  Rect _animatedCropRect = Rect.zero;
  Rect _targetCropRect = Rect.zero;

  // Crop window state
  Rect _cropRect = Rect.zero;
  bool _isInit = false;
  bool _hasFitImage = false;
  bool _isTransitioning = false;

  // Rotation
  double _rotation = 0.0;
  double _targetRotation = 0.0;

  // Track if user has manually resized the crop rect
  bool _userHasResized = false;

  // Animation controllers for spring physics
  AnimationController? _rotationAnimationController;
  AnimationController? _matrixAnimationController;
  AnimationController? _cropRectAnimationController;

  // For velocity-based spring animations
  double _lastDragVelocity = 0.0;
  Offset _lastVelocityVector = Offset.zero;

  // Gesture tracking
  bool _isInteracting = false;

  // Two-finger rotation gesture tracking
  double _previousRotationGestureAngle = 0.0;
  bool _isRotationGesture = false;
  int _pointerCount = 0;

  // Caching for expensive physics calculations
  double? _cachedRotationForMinScale;
  double? _cachedMinScale;

  // Flag to track if initial settings should be applied after image loads
  bool _shouldApplyInitialSettings = false;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _transitionAnimation = CurvedAnimation(
      parent: _transitionController,
      curve: Curves.easeOutCubic,
    );
    _transitionController.addListener(_onTransitionUpdate);

    _shouldApplyInitialSettings = widget.initialSettings != null;
    if (_shouldApplyInitialSettings) {
      _rotation = widget.initialSettings!.rotation;
    }

    _loadImage();
  }

  void _onTransitionUpdate() {
    if (!mounted) return;
    setState(() {
      _animatedCropRect =
          Rect.lerp(_cropRect, _targetCropRect, _transitionAnimation.value)!;
    });
  }

  @override
  void dispose() {
    _image?.dispose();
    _transformationController.dispose();
    _transitionController.removeListener(_onTransitionUpdate);
    _transitionController.dispose();
    _rotationAnimationController?.dispose();
    _matrixAnimationController?.dispose();
    _cropRectAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      // Use FlutterImageCompress to normalize the image before loading.
      // This handles iOS 10-bit HDR/HEIF images that Flutter's codec can't decode.
      Uint8List? data = widget.imageBytes;

      if (!kIsWeb) {
        final compressedBytes = await FlutterImageCompress.compressWithList(
          widget.imageBytes,
          quality: 95,
          keepExif: true,
          format: CompressFormat.jpeg,
        );
        data = compressedBytes;
      }

      final buffer = await ui.instantiateImageCodec(data);
      final frame = await buffer.getNextFrame();

      if (mounted) {
        setState(() {
          _image = frame.image;
          _isLoading = false;
          _isInit = false;
          _hasFitImage = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('🖼️ Image loading error: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pop();
      }
    }
  }

  void _resetTransform() {
    setState(() {
      _rotation = 0.0;
      _isInit = false;
      _userHasResized = false;
    });
  }

  void _onCropRectChanged(Rect newRect, CropHandle handle) {
    if (!mounted || _image == null) return;

    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();
    final minScale = _calculateMinScaleForRotation(
      imageWidth: imgW,
      imageHeight: imgH,
      cropWidth: newRect.width,
      cropHeight: newRect.height,
      rotation: _rotation,
    );

    final matrix = _transformationController.value.clone();
    final currentScale = matrix.getMaxScaleOnAxis();

    if (currentScale < minScale) {
      final scaleFactor = minScale / currentScale;

      final Offset anchor;
      final rect = _cropRect;

      anchor = switch (handle) {
        CropHandle.topLeft => rect.bottomRight,
        CropHandle.topRight => rect.bottomLeft,
        CropHandle.bottomLeft => rect.topRight,
        CropHandle.bottomRight => rect.topLeft,
        CropHandle.top => Offset(rect.center.dx, rect.bottom),
        CropHandle.bottom => Offset(rect.center.dx, rect.top),
        CropHandle.left => Offset(rect.right, rect.center.dy),
        CropHandle.right => Offset(rect.left, rect.center.dy),
        _ => rect.center,
      };

      final scaleMatrix = Matrix4.identity()
        ..translate(anchor.dx, anchor.dy)
        ..scale(scaleFactor)
        ..translate(-anchor.dx, -anchor.dy);

      final newMatrix = scaleMatrix * matrix as Matrix4;
      _transformationController.value = newMatrix;
    }

    final violation = _calculateBoundaryViolationForMatrix(
      _transformationController.value,
      rotation: _rotation,
      customCropRect: newRect,
    );

    if (violation.distance > 0.1) {
      final m = _transformationController.value;
      m.setTranslationRaw(
        m.storage[12] + violation.dx,
        m.storage[13] + violation.dy,
        m.storage[14],
      );
      _transformationController.value = m;
    }

    setState(() {
      _cropRect = newRect;
      _animatedCropRect = newRect;
      _targetCropRect = newRect;
      _userHasResized = true;
    });
  }

  void _onResizeStart() {}

  void _onResizeEnd() {
    _enforceMinimumCoverage();
    _animateCropRectToCenter();
  }

  void _onRotationChanged(double newRotation) {
    _rotationAnimationController?.stop();
    _adjustScaleForRotation(newRotation);
    _rotation = newRotation;

    final violation = _calculateBoundaryViolationForMatrix(
      _transformationController.value,
      rotation: newRotation,
    );
    if (violation.distance > 0.1) {
      final matrix = _transformationController.value.clone();
      matrix.setTranslationRaw(
        matrix.storage[12] + violation.dx,
        matrix.storage[13] + violation.dy,
        matrix.storage[14],
      );
      _transformationController.value = matrix;
    }

    setState(() {});
  }

  void _onRotationEnd(double targetRotation) {
    _animateRotation(targetRotation);
    _enforceMinimumCoverageWithMomentum();
  }

  void _adjustScaleForRotation(double rotation, {bool isScalingDown = false}) {
    if (_image == null) return;

    final matrix = _transformationController.value;
    final currentScale = matrix.getMaxScaleOnAxis();
    final rect = _hasFitImage ? _animatedCropRect : _cropRect;

    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();

    final minScaleForRotation = _calculateMinScaleForRotation(
      imageWidth: imgW,
      imageHeight: imgH,
      cropWidth: rect.width,
      cropHeight: rect.height,
      rotation: rotation,
    );

    if (currentScale < minScaleForRotation) {
      if (_isInteracting && isScalingDown) return;

      final scaleFactor = minScaleForRotation / currentScale;
      final focalPoint = rect.center;

      final scaleMatrix = Matrix4.identity()
        ..translate(focalPoint.dx, focalPoint.dy)
        ..scale(scaleFactor)
        ..translate(-focalPoint.dx, -focalPoint.dy);

      final targetMatrix = scaleMatrix * matrix as Matrix4;
      _transformationController.value = targetMatrix;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount >= 2) {
      _isRotationGesture = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerCount--;

    if (_isRotationGesture && _pointerCount < 2) {
      _isRotationGesture = false;
      _previousRotationGestureAngle = 0.0;

      final nearestQuarter =
          (_rotation / (math.pi / 2)).round() * (math.pi / 2);
      final diff = (_rotation - nearestQuarter).abs();
      if (diff < 0.087) {
        _animateRotation(nearestQuarter);
      }

      _enforceMinimumCoverageWithMomentum();
    }

    if (_pointerCount < 0) _pointerCount = 0;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerCount--;
    if (_pointerCount < 0) _pointerCount = 0;

    if (_isRotationGesture && _pointerCount < 2) {
      _isRotationGesture = false;
      _previousRotationGestureAngle = 0.0;
      _enforceMinimumCoverageWithMomentum();
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_pointerCount >= 2 && details.pointerCount >= 2) {
      final currentAngle = details.rotation;

      if (_previousRotationGestureAngle == 0.0 && currentAngle != 0.0) {
        _previousRotationGestureAngle = currentAngle;
        return;
      }

      final rotationDelta = currentAngle - _previousRotationGestureAngle;
      final newRotation = _rotation + rotationDelta * _kRotationSensitivity;
      final clampedRotation = newRotation.clamp(-math.pi / 4, math.pi / 4);

      if ((clampedRotation - _rotation).abs() > 0.001) {
        _rotationAnimationController?.stop();
        _adjustScaleForRotation(clampedRotation,
            isScalingDown: details.scale < 1.0);

        setState(() {
          _rotation = clampedRotation;
        });
      }

      _previousRotationGestureAngle = currentAngle;
    }

    _applyBoundaryClampingDuringGesture();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _isInteracting = true;
    _matrixAnimationController?.stop();

    if (details.pointerCount >= 2) {
      _isRotationGesture = true;
      _previousRotationGestureAngle = 0.0;
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isInteracting = false;

    _lastVelocityVector = details.velocity.pixelsPerSecond;
    _lastDragVelocity = _lastVelocityVector.distance / 1000.0;

    if (_isRotationGesture) {
      _isRotationGesture = false;
      _previousRotationGestureAngle = 0.0;

      final nearestQuarter =
          (_rotation / (math.pi / 2)).round() * (math.pi / 2);
      final diff = (_rotation - nearestQuarter).abs();
      if (diff < 0.087) {
        _animateRotation(nearestQuarter);
      }
    }

    _enforceMinimumCoverageWithMomentum();
  }

  void _animateRotation(double targetRotation) {
    _rotationAnimationController?.dispose();

    _targetRotation = targetRotation;

    _rotationAnimationController = AnimationController.unbounded(vsync: this);

    final simulation = SpringSimulation(
      _kLightSpringDescription,
      _rotation,
      targetRotation,
      0.0,
    );

    _rotationAnimationController!.addListener(() {
      if (!mounted) return;
      final newRotation = _rotationAnimationController!.value;
      _adjustScaleForRotation(newRotation);
      setState(() {
        _rotation = newRotation;
      });
    });

    _rotationAnimationController!.animateWith(simulation).then((_) {
      if (!mounted) return;
      _adjustScaleForRotation(_targetRotation);
      setState(() {
        _rotation = _targetRotation;
      });
    });
  }

  void _onZoomIn() {
    final matrix = _transformationController.value.clone();
    final rect = _hasFitImage ? _animatedCropRect : _cropRect;
    final focalPoint = rect.center;

    final scaleMatrix = Matrix4.identity()
      ..translate(focalPoint.dx, focalPoint.dy)
      ..scale(1.15)
      ..translate(-focalPoint.dx, -focalPoint.dy);

    final targetMatrix = scaleMatrix * matrix as Matrix4;
    _animateToMatrixWithSpring(targetMatrix, velocity: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Content Area (Image + Cropper)
          if (_isLoading)
            Center(
              child: CircularProgressIndicator.adaptive(
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.loadingIndicatorColor),
              ),
            )
          else
            _buildCropperBody(),

          // 2. Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CropperAppBar(onReset: _resetTransform, theme: theme),
          ),

          // 3. Bottom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CropperBottomControls(
              rotation: _rotation,
              onRotationChanged: _onRotationChanged,
              onRotationEnd: _onRotationEnd,
              onZoomIn: _onZoomIn,
              onCrop: _cropImage,
              isCropping: _isCropping,
              theme: theme,
            ),
          ),

          // 4. Loading Overlay
          if (_isCropping)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      theme.loadingIndicatorColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCropperBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final newCropRect = _calculateCropRect(constraints.biggest);

        if ((!_isInit || newCropRect != _cropRect) &&
            !_isTransitioning &&
            !_userHasResized) {
          final oldCropRect = _cropRect;
          _targetCropRect = newCropRect;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (!_hasFitImage) {
              _cropRect = newCropRect;
              _animatedCropRect = newCropRect;
              _fitImageToRect(newCropRect);
              setState(() {
                _isInit = true;
                _hasFitImage = true;
              });
            } else {
              setState(() {
                _isTransitioning = true;
                _cropRect = oldCropRect;
              });

              _transitionController.reset();
              _transitionController.forward().then((_) {
                if (!mounted) return;
                setState(() {
                  _cropRect = newCropRect;
                  _animatedCropRect = newCropRect;
                  _isInit = true;
                  _isTransitioning = false;
                });
                _fitImageToRect(newCropRect, animated: true);
              });
            }
          });

          _isInit = true;
        }

        final showImage = _hasFitImage && _image != null;
        final displayRect = _hasFitImage ? _animatedCropRect : _targetCropRect;
        final theme = widget.theme;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Interactive Image Layer
            Listener(
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: GestureDetector(
                onDoubleTap: _resetTransform,
                child: RepaintBoundary(
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.1,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    constrained: false,
                    onInteractionStart: _handleScaleStart,
                    onInteractionUpdate: _handleScaleUpdate,
                    onInteractionEnd: _handleScaleEnd,
                    child: showImage
                        ? Transform.rotate(
                            angle: _rotation,
                            child: RawImage(
                              image: _image!,
                              fit: BoxFit.none,
                              filterQuality: FilterQuality.medium,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // Overlay Layer with animated crop rect
            IgnorePointer(
              child: Stack(
                children: [
                  // Blur layer - only outside crop area
                  ClipPath(
                    clipper: CropperInvertedClipper(
                      cropRect: displayRect,
                      cornerRadius: theme.cropCornerRadius,
                    ),
                    child: theme.overlayBlurSigma > 0 &&
                            !kIsWeb &&
                            theme.blurEnabledPlatforms
                                .contains(defaultTargetPlatform)
                        ? BackdropFilter(
                            filter: ui.ImageFilter.blur(
                              sigmaX: theme.overlayBlurSigma,
                              sigmaY: theme.overlayBlurSigma,
                            ),
                            child: Container(color: theme.overlayColor),
                          )
                        : Container(color: theme.overlayColor),
                  ),
                  // Grid and border overlay
                  CustomPaint(
                    painter: CropperOverlayPainter(
                        cropRect: displayRect, theme: theme),
                    size: Size.infinite,
                  ),
                ],
              ),
            ),

            // Resize Handles Layer
            if (_hasFitImage)
              CropperResizeHandles(
                cropRect: displayRect,
                onCropRectChanged: _onCropRectChanged,
                onResizeStart: _onResizeStart,
                onResizeEnd: _onResizeEnd,
                containerSize: constraints.biggest,
                minSize: 80.0,
              ),
          ],
        );
      },
    );
  }

  Rect _calculateCropRect(Size availableSize) {
    const topPadding = 100.0;
    const bottomPadding = 210.0;
    const horizontalPadding = 15.0;

    final usableWidth = availableSize.width - 2 * horizontalPadding;
    final usableHeight = availableSize.height - topPadding - bottomPadding;

    final center =
        Offset(availableSize.width / 2, topPadding + (usableHeight / 2));

    double width = usableWidth;
    double height = usableWidth;

    if (_image != null) {
      final imgRatio = _image!.width / _image!.height;
      if (imgRatio > 1) {
        width = usableWidth;
        height = width / imgRatio;
        if (height > usableHeight) {
          height = usableHeight;
          width = height * imgRatio;
        }
      } else {
        height = usableHeight;
        width = height * imgRatio;
        if (width > usableWidth) {
          width = usableWidth;
          height = width / imgRatio;
        }
      }
    }

    return Rect.fromCenter(center: center, width: width, height: height);
  }

  void _fitImageToRect(Rect rect, {bool animated = false}) {
    if (_image == null) return;

    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();

    Matrix4 matrix;

    if (_shouldApplyInitialSettings && widget.initialSettings != null) {
      final settings = widget.initialSettings!;

      if (settings.cropRectWidth > 0 && settings.cropRectHeight > 0) {
        _cropRect = Rect.fromLTWH(
          settings.cropRectLeft,
          settings.cropRectTop,
          settings.cropRectWidth,
          settings.cropRectHeight,
        );
        _animatedCropRect = _cropRect;
        _targetCropRect = _cropRect;
      }

      double scale = settings.scale;
      if (scale > 5.0) scale = 5.0;

      matrix = Matrix4.identity();
      matrix.scale(scale);
      matrix.setTranslationRaw(settings.offsetX, settings.offsetY, 0);

      _shouldApplyInitialSettings = false;
      _userHasResized = true;
    } else {
      double scale = _calculateMinScaleForRotation(
        imageWidth: imgW,
        imageHeight: imgH,
        cropWidth: rect.width,
        cropHeight: rect.height,
        rotation: _rotation,
      );

      if (scale > 5.0) scale = 5.0;

      matrix = Matrix4.identity();
      matrix.scale(scale);

      final imageCenter = Offset(imgW * scale / 2, imgH * scale / 2);
      final rectCenter = rect.center;

      final dx = rectCenter.dx - imageCenter.dx;
      final dy = rectCenter.dy - imageCenter.dy;

      matrix.setTranslationRaw(dx, dy, 0);
    }

    if (animated) {
      _animateToMatrix(matrix);
    } else {
      _transformationController.value = matrix;
    }
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _animateToMatrixWithSpring(targetMatrix, velocity: 0.0);
  }

  void _animateToMatrixWithSpring(Matrix4 targetMatrix,
      {double velocity = 0.0}) {
    _matrixAnimationController?.dispose();

    final startMatrix = _transformationController.value.clone();
    _matrixAnimationController = AnimationController.unbounded(vsync: this);

    final simulation = SpringSimulation(
      _kAppleSpringDescription,
      0.0,
      1.0,
      velocity,
    );

    void listener() {
      if (!mounted) {
        _matrixAnimationController?.dispose();
        return;
      }

      final t = _matrixAnimationController!.value;

      final Matrix4 current = Matrix4.identity();
      for (int i = 0; i < 16; i++) {
        current.storage[i] =
            ui.lerpDouble(startMatrix.storage[i], targetMatrix.storage[i], t)!;
      }
      _transformationController.value = current;
    }

    _matrixAnimationController!.addListener(listener);
    _matrixAnimationController!.animateWith(simulation).then((_) {
      _matrixAnimationController?.removeListener(listener);
      if (mounted) {
        _transformationController.value = targetMatrix;
      }
    });
  }

  (double maxDu, double maxDv) _calculateSafeMarginsForRotation({
    required double scaledWidth,
    required double scaledHeight,
    required double rotation,
    required double cropWidth,
    required double cropHeight,
  }) {
    final absRotation = rotation.abs();

    final sinR = math.sin(absRotation).abs();
    final cosR = math.cos(absRotation).abs();

    final maxDu = math.max(
        0.0, (scaledWidth - (cropWidth * cosR + cropHeight * sinR)) / 2);
    final maxDv = math.max(
        0.0, (scaledHeight - (cropWidth * sinR + cropHeight * cosR)) / 2);

    return (maxDu, maxDv);
  }

  Offset _calculateBoundaryViolation() {
    return _calculateBoundaryViolationForMatrix(
        _transformationController.value);
  }

  void _applyBoundaryClampingDuringGesture() {
    if (_image == null || !_isInteracting) return;

    final matrix = _transformationController.value;
    final violation = _calculateBoundaryViolation();

    if (violation.distance > 1.0) {
      final targetMatrix = matrix.clone();

      final dx = violation.dx * _kRubberBandFactor;
      final dy = violation.dy * _kRubberBandFactor;

      targetMatrix.setTranslationRaw(
        targetMatrix.storage[12] + dx,
        targetMatrix.storage[13] + dy,
        targetMatrix.storage[14],
      );

      _transformationController.value = targetMatrix;
    }
  }

  void _enforceMinimumCoverageWithMomentum() {
    if (_image == null) return;

    final matrix = _transformationController.value;
    final currentScale = matrix.getMaxScaleOnAxis();
    final rect = _hasFitImage ? _animatedCropRect : _cropRect;

    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();

    if (_cachedRotationForMinScale != _rotation || _cachedMinScale == null) {
      _cachedMinScale = _calculateMinScaleForRotation(
        imageWidth: imgW,
        imageHeight: imgH,
        cropWidth: rect.width,
        cropHeight: rect.height,
        rotation: _rotation,
      );
      _cachedRotationForMinScale = _rotation;
    }
    final minScale = _cachedMinScale!;

    Matrix4 targetMatrix = matrix.clone();
    bool needsAnimation = false;

    if (currentScale < minScale) {
      needsAnimation = true;
      final scaleFactor = minScale / currentScale;
      final focalPoint = rect.center;

      final scaleMatrix = Matrix4.identity()
        ..translate(focalPoint.dx, focalPoint.dy)
        ..scale(scaleFactor)
        ..translate(-focalPoint.dx, -focalPoint.dy);

      targetMatrix = scaleMatrix * targetMatrix as Matrix4;
    }

    final violation = _calculateBoundaryViolationForMatrix(targetMatrix);

    if (violation.distance > 0.1) {
      needsAnimation = true;
      targetMatrix.setTranslationRaw(
        targetMatrix.storage[12] + violation.dx,
        targetMatrix.storage[13] + violation.dy,
        targetMatrix.storage[14],
      );
    }

    if (needsAnimation) {
      double velocityMagnitude = 0.0;
      if (_lastVelocityVector.distance > _kMinVelocityThreshold) {
        final double dist = violation.distance;
        if (dist > 1.0) {
          final snapDirection = Offset(violation.dx, violation.dy) / dist;
          final velocityInSnapDirection =
              _lastVelocityVector.dx * snapDirection.dx +
                  _lastVelocityVector.dy * snapDirection.dy;

          velocityMagnitude = (velocityInSnapDirection / dist).clamp(-5.0, 5.0);
        }
      }

      _animateSnapBack(targetMatrix, velocity: velocityMagnitude);
    }
  }

  void _animateSnapBack(Matrix4 targetMatrix, {double velocity = 0.0}) {
    _matrixAnimationController?.dispose();

    final startMatrix = _transformationController.value.clone();
    _matrixAnimationController = AnimationController.unbounded(vsync: this);

    final simulation = SpringSimulation(
        _kBounceBackSpring, 0.0, 1.0, velocity.clamp(-2.0, 2.0));

    void listener() {
      if (!mounted) {
        _matrixAnimationController?.dispose();
        return;
      }

      final t = _matrixAnimationController!.value;

      final Matrix4 current = Matrix4.identity();
      for (int i = 0; i < 16; i++) {
        current.storage[i] =
            ui.lerpDouble(startMatrix.storage[i], targetMatrix.storage[i], t)!;
      }
      _transformationController.value = current;
    }

    _matrixAnimationController!.addListener(listener);
    _matrixAnimationController!.animateWith(simulation).then((_) {
      _matrixAnimationController?.removeListener(listener);
      if (mounted) {
        _transformationController.value = targetMatrix;
      }
    });
  }

  Offset _calculateBoundaryViolationForMatrix(
    Matrix4 matrix, {
    double? rotation,
    Rect? customCropRect,
  }) {
    if (_image == null) return Offset.zero;

    final rotationToUse = rotation ?? _rotation;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();
    final rect =
        customCropRect ?? (_hasFitImage ? _animatedCropRect : _cropRect);

    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();

    final scaledImgW = imgW * scale;
    final scaledImgH = imgH * scale;

    final dX = (translation.x + scaledImgW / 2) - rect.center.dx;
    final dY = (translation.y + scaledImgH / 2) - rect.center.dy;

    final cosR = math.cos(rotationToUse);
    final sinR = math.sin(rotationToUse);

    final du = dX * cosR + dY * sinR;
    final dv = -dX * sinR + dY * cosR;

    final (maxDu, maxDv) = _calculateSafeMarginsForRotation(
      scaledWidth: scaledImgW,
      scaledHeight: scaledImgH,
      rotation: rotationToUse,
      cropWidth: rect.width,
      cropHeight: rect.height,
    );

    double shiftDu = 0;
    if (du > maxDu) {
      shiftDu = maxDu - du;
    } else if (du < -maxDu) {
      shiftDu = -maxDu - du;
    }

    double shiftDv = 0;
    if (dv > maxDv) {
      shiftDv = maxDv - dv;
    } else if (dv < -maxDv) {
      shiftDv = -maxDv - dv;
    }

    if (shiftDu.abs() < 0.1 && shiftDv.abs() < 0.1) return Offset.zero;

    final shiftDx = shiftDu * cosR - shiftDv * sinR;
    final shiftDy = shiftDu * sinR + shiftDv * cosR;

    return Offset(shiftDx, shiftDy);
  }

  Matrix4 _getConstrainedMatrix(Matrix4 matrix, {Rect? customCropRect}) {
    if (_image == null) return matrix;

    final currentScale = matrix.getMaxScaleOnAxis();
    final rect =
        customCropRect ?? (_hasFitImage ? _animatedCropRect : _cropRect);

    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();
    final minScale = _calculateMinScaleForRotation(
      imageWidth: imgW,
      imageHeight: imgH,
      cropWidth: rect.width,
      cropHeight: rect.height,
      rotation: _rotation,
    );

    Matrix4 targetMatrix = matrix.clone();

    if (currentScale < minScale) {
      final scaleFactor = minScale / currentScale;
      final focalPoint = rect.center;

      final scaleMatrix = Matrix4.identity()
        ..translate(focalPoint.dx, focalPoint.dy)
        ..scale(scaleFactor)
        ..translate(-focalPoint.dx, -focalPoint.dy);

      targetMatrix = scaleMatrix * targetMatrix as Matrix4;
    }

    final violation = _calculateBoundaryViolationForMatrix(
      targetMatrix,
      rotation: _rotation,
      customCropRect: rect,
    );
    if (violation.distance > 0.1) {
      targetMatrix.setTranslationRaw(
        targetMatrix.storage[12] + violation.dx,
        targetMatrix.storage[13] + violation.dy,
        targetMatrix.storage[14],
      );
    }

    return targetMatrix;
  }

  void _enforceMinimumCoverage() {
    if (_image == null) return;

    final targetMatrix = _getConstrainedMatrix(_transformationController.value);

    if (targetMatrix != _transformationController.value) {
      final startPos = _transformationController.value.getTranslation();
      final endPos = targetMatrix.getTranslation();
      final dist = (Offset(endPos.x, endPos.y) - Offset(startPos.x, startPos.y))
          .distance;

      double velocityMagnitude = 0.0;
      if (dist > 1.0) {
        velocityMagnitude =
            (_lastDragVelocity * 1000.0 / dist).clamp(-5.0, 5.0);
      }

      _animateSnapBack(targetMatrix, velocity: velocityMagnitude);
    }
  }

  void _animateCropRectToCenter() {
    if (_image == null || !_hasFitImage) return;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    const topPadding = 100.0;
    const bottomPadding = 210.0;
    final usableHeight = screenSize.height - topPadding - bottomPadding;
    final targetCenter =
        Offset(screenSize.width / 2, topPadding + (usableHeight / 2));

    final currentCenter = _cropRect.center;

    final centerDelta = targetCenter - currentCenter;
    if (centerDelta.distance < 1.0) return;

    _cropRectAnimationController?.dispose();
    _cropRectAnimationController = AnimationController.unbounded(vsync: this);

    final startCropRect = _cropRect;
    final startMatrix = _transformationController.value.clone();

    final targetCropRect = Rect.fromCenter(
      center: targetCenter,
      width: _cropRect.width,
      height: _cropRect.height,
    );

    final targetMatrix = startMatrix.clone();
    targetMatrix.setTranslationRaw(
      startMatrix.storage[12] + centerDelta.dx,
      startMatrix.storage[13] + centerDelta.dy,
      startMatrix.storage[14],
    );

    final simulation = SpringSimulation(_kCenteringSpring, 0.0, 1.0, 0.0);

    void listener() {
      if (!mounted) {
        _cropRectAnimationController?.dispose();
        return;
      }

      final t = _cropRectAnimationController!.value;

      final currentCropRect = Rect.lerp(startCropRect, targetCropRect, t)!;

      final Matrix4 currentMatrix = Matrix4.identity();
      for (int i = 0; i < 16; i++) {
        currentMatrix.storage[i] = ui.lerpDouble(
          startMatrix.storage[i],
          targetMatrix.storage[i],
          t,
        )!;
      }

      setState(() {
        _cropRect = currentCropRect;
        _animatedCropRect = currentCropRect;
        _targetCropRect = currentCropRect;
      });
      _transformationController.value = currentMatrix;
    }

    _cropRectAnimationController!.addListener(listener);
    _cropRectAnimationController!.animateWith(simulation).then((_) {
      _cropRectAnimationController?.removeListener(listener);
      if (mounted) {
        setState(() {
          _cropRect = targetCropRect;
          _animatedCropRect = targetCropRect;
          _targetCropRect = targetCropRect;
        });
        _transformationController.value = targetMatrix;
      }
    });
  }

  Future<void> _cropImage() async {
    if (_image == null) return;
    setState(() => _isCropping = true);

    try {
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);

      final matrix = _getConstrainedMatrix(_transformationController.value);

      final inverse = Matrix4.tryInvert(matrix);
      if (inverse == null) throw Exception("Invalid matrix");

      final rect = _cropRect;

      double outputScale = 1.0;
      final currentScale = matrix.getMaxScaleOnAxis();
      if (currentScale < 1.0) outputScale = 1.0 / currentScale;

      if (rect.width * outputScale > 3000) outputScale = 3000 / rect.width;
      if (rect.height * outputScale > 3000) outputScale = 3000 / rect.height;

      final outW = (rect.width * outputScale).toInt();
      final outH = (rect.height * outputScale).toInt();

      canvas.scale(outputScale);
      canvas.translate(-rect.left, -rect.top);
      canvas.transform(matrix.storage);

      _drawImageWithRotation(canvas, _image!, _rotation);

      final picture = pictureRecorder.endRecording();
      final img = await picture.toImage(outW, outH);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final buffer = byteData.buffer.asUint8List();

        final settings = CropSettings(
          scale: matrix.getMaxScaleOnAxis(),
          offsetX: matrix.storage[12],
          offsetY: matrix.storage[13],
          rotation: _rotation,
          aspectRatio: rect.width / rect.height,
          cropRectLeft: rect.left,
          cropRectTop: rect.top,
          cropRectWidth: rect.width,
          cropRectHeight: rect.height,
        );

        if (mounted) {
          Navigator.of(context)
              .pop(CropResult(bytes: buffer, settings: settings));
        }
      }
    } catch (e) {
      debugPrint("Crop error: $e");
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  void _drawImageWithRotation(Canvas canvas, ui.Image image, double rotation) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    canvas.save();

    canvas.translate(imgW / 2, imgH / 2);
    canvas.rotate(rotation);
    canvas.translate(-imgW / 2, -imgH / 2);

    canvas.drawImage(
        image, Offset.zero, Paint()..filterQuality = FilterQuality.high);

    canvas.restore();
  }
}
