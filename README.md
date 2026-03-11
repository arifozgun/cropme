# Cropme

An Apple Photos-style image cropper for Flutter with spring physics, rotation trackbar, free-form resize handles, and rubber-band snap-back animations.

## ✨ Features

- **Apple Photos-style UX** — Spring physics animations for natural, satisfying crop interactions
- **Free-form cropping** — Drag edges and corners to resize the crop area
- **Rotation trackbar** — Precise rotation control with haptic feedback at key angles
- **Two-finger rotation** — Pinch-rotate gesture with ±45° range
- **Rubber-band snap-back** — Smooth bounce-back when pulling beyond boundaries
- **Rotation-aware boundaries** — Crop rect always stays within rotated image bounds (no black corners)
- **Save & restore** — `CropSettings` lets you restore previous crop state when re-editing
- **HDR/HEIF support** — Automatically normalizes iOS HDR images via `flutter_image_compress`
- **Customizable theming** — Full color, text, and label customization via `CropperThemeData`
- **Platform-adaptive** — Blur overlay on iOS, solid overlay on Android for performance

## 📦 Installation

```yaml
dependencies:
  cropme: ^0.0.1
```

## 🚀 Usage

### Basic

```dart
import 'dart:io';
import 'package:cropme/cropme.dart';

// Show the image cropper and get the result
final result = await ImageCropper.show(
  context: context,
  imageFile: File('/path/to/image.jpg'),
);

if (result != null) {
  final croppedFile = result.file as File;
  final settings = result.settings; // Save for re-editing later
}
```

### With Custom Theme

```dart
final result = await ImageCropper.show(
  context: context,
  imageFile: imageFile,
  theme: CropperThemeData(
    backgroundColor: Colors.black,
    accentColor: Colors.amber,
    cropLabel: 'Done',
    resetLabel: 'Reset',
    cropCornerRadius: 16.0,
  ),
);
```

### Restore Previous Crop

```dart
// Save settings from previous crop
final savedSettings = previousResult.settings;

// Restore when re-editing
final result = await ImageCropper.show(
  context: context,
  imageFile: imageFile,
  initialSettings: savedSettings,
);
```

### Using as a Widget

```dart
ImageCropper(
  imageFile: imageFile,
  initialSettings: savedSettings,
  theme: CropperThemeData(accentColor: Colors.orange),
)
```

## ⚙️ API

### ImageCropper

| Property | Type | Default | Description |
|---|---|---|---|
| `imageFile` | `File` | Required | Source image file to crop |
| `initialSettings` | `CropSettings?` | `null` | Restore previous crop state |
| `theme` | `CropperThemeData` | Default dark | Theme configuration |

### ImageCropper.show()

| Parameter | Type | Default | Description |
|---|---|---|---|
| `context` | `BuildContext` | Required | Build context for navigation |
| `imageFile` | `File` | Required | Source image file |
| `initialSettings` | `CropSettings?` | `null` | Restore previous crop state |
| `theme` | `CropperThemeData` | Default dark | Theme configuration |

**Returns:** `Future<CropResult?>` — `null` if user cancels

### CropResult

| Property | Type | Description |
|---|---|---|
| `file` | `dynamic` | The cropped image `File` |
| `settings` | `CropSettings` | Settings used (save for re-editing) |

### CropperThemeData

| Property | Type | Default | Description |
|---|---|---|---|
| `backgroundColor` | `Color` | `#000000` | Scaffold background |
| `overlayColor` | `Color` | `#99000000` | Area outside crop rect |
| `gridLineColor` | `Color` | `#33FFFFFF` | Rule-of-thirds grid |
| `accentColor` | `Color` | `#FFC107` | Rotation indicator |
| `buttonBackgroundColor` | `Color` | `#2C2C2E` | Glass button background |
| `buttonTextColor` | `Color` | `#FFFFFF` | Button text |
| `cropCornerRadius` | `double` | `12.0` | Crop rect corner radius |
| `resetLabel` | `String` | `'Reset'` | Reset button text |
| `cropLabel` | `String` | `'Crop & Save'` | Crop button text |

## 📋 Requirements

- Flutter 3.10+
- Dart 3.0+

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
