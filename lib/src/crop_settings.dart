import 'dart:typed_data';

/// Model class to store crop settings for restoring crop state when re-editing.
///
/// This allows the cropper to restore the previous crop configuration
/// when the user re-opens the cropper for the same image.
class CropSettings {
  /// Scale factor applied to the image (1.0 = original, > 1.0 = zoomed in)
  final double scale;

  /// X offset of the image transformation matrix
  final double offsetX;

  /// Y offset of the image transformation matrix
  final double offsetY;

  /// Rotation angle in radians (typically -π/4 to π/4)
  final double rotation;

  /// Aspect ratio of the crop rect (width / height).
  /// null means free-form crop (no fixed ratio).
  final double? aspectRatio;

  /// Crop rect coordinates in screen space (relative to cropper view).
  /// This allows the crop rect to be restored exactly as it was last edited.
  final double cropRectLeft;
  final double cropRectTop;
  final double cropRectWidth;
  final double cropRectHeight;

  const CropSettings({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.rotation,
    this.aspectRatio,
    required this.cropRectLeft,
    required this.cropRectTop,
    required this.cropRectWidth,
    required this.cropRectHeight,
  });

  /// Default settings (no transformation applied).
  factory CropSettings.initial() => const CropSettings(
    scale: 1.0,
    offsetX: 0.0,
    offsetY: 0.0,
    rotation: 0.0,
    aspectRatio: null,
    cropRectLeft: 0.0,
    cropRectTop: 0.0,
    cropRectWidth: 1.0,
    cropRectHeight: 1.0,
  );

  /// Create a copy with optional modifications.
  CropSettings copyWith({
    double? scale,
    double? offsetX,
    double? offsetY,
    double? rotation,
    double? aspectRatio,
    double? cropRectLeft,
    double? cropRectTop,
    double? cropRectWidth,
    double? cropRectHeight,
  }) {
    return CropSettings(
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      rotation: rotation ?? this.rotation,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      cropRectLeft: cropRectLeft ?? this.cropRectLeft,
      cropRectTop: cropRectTop ?? this.cropRectTop,
      cropRectWidth: cropRectWidth ?? this.cropRectWidth,
      cropRectHeight: cropRectHeight ?? this.cropRectHeight,
    );
  }

  /// Convert to Map for serialization (e.g., saving to SharedPreferences).
  Map<String, dynamic> toMap() => {
    'scale': scale,
    'offsetX': offsetX,
    'offsetY': offsetY,
    'rotation': rotation,
    'aspectRatio': aspectRatio,
    'cropRectLeft': cropRectLeft,
    'cropRectTop': cropRectTop,
    'cropRectWidth': cropRectWidth,
    'cropRectHeight': cropRectHeight,
  };

  /// Create from Map (e.g., loaded from SharedPreferences).
  factory CropSettings.fromMap(Map<String, dynamic> map) => CropSettings(
    scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
    offsetX: (map['offsetX'] as num?)?.toDouble() ?? 0.0,
    offsetY: (map['offsetY'] as num?)?.toDouble() ?? 0.0,
    rotation: (map['rotation'] as num?)?.toDouble() ?? 0.0,
    aspectRatio: (map['aspectRatio'] as num?)?.toDouble(),
    cropRectLeft: (map['cropRectLeft'] as num?)?.toDouble() ?? 0.0,
    cropRectTop: (map['cropRectTop'] as num?)?.toDouble() ?? 0.0,
    cropRectWidth: (map['cropRectWidth'] as num?)?.toDouble() ?? 1.0,
    cropRectHeight: (map['cropRectHeight'] as num?)?.toDouble() ?? 1.0,
  );

  @override
  String toString() =>
      'CropSettings(scale: $scale, offset: ($offsetX, $offsetY), rotation: $rotation, aspectRatio: $aspectRatio)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CropSettings &&
          runtimeType == other.runtimeType &&
          scale == other.scale &&
          offsetX == other.offsetX &&
          offsetY == other.offsetY &&
          rotation == other.rotation &&
          aspectRatio == other.aspectRatio &&
          cropRectLeft == other.cropRectLeft &&
          cropRectTop == other.cropRectTop &&
          cropRectWidth == other.cropRectWidth &&
          cropRectHeight == other.cropRectHeight;

  @override
  int get hashCode => Object.hash(
    scale,
    offsetX,
    offsetY,
    rotation,
    aspectRatio,
    cropRectLeft,
    cropRectTop,
    cropRectWidth,
    cropRectHeight,
  );
}

/// Result class containing both the cropped file and the settings used.
class CropResult {
  /// The cropped image bytes.
  final Uint8List bytes;

  /// The crop settings used (for restoring state on re-edit).
  final CropSettings settings;

  const CropResult({required this.bytes, required this.settings});
}
