# Cropme

An Apple Photos-style image cropper for Flutter with spring physics, rotation trackbar, free-form resize handles, and rubber-band snap-back animations.

![Flutter Cropme Example Demo](https://github.com/user-attachments/assets/2b7099fb-c8b7-4d49-a53c-25d3c8c2f3aa)
<img src="https://github.com/user-attachments/assets/87a6233e-66c3-4c5d-a972-816c7d058961" height="668"/>


## Features

- **Apple Photos-style UX** -- Spring physics animations for natural, satisfying crop interactions
- **Free-form cropping** -- Drag edges and corners to resize the crop area
- **Rotation trackbar** -- Precise rotation control with haptic feedback at key angles
- **Two-finger rotation** -- Pinch-rotate gesture with a range of 45 degrees
- **Rubber-band snap-back** -- Smooth bounce-back when pulling beyond boundaries
- **Rotation-aware boundaries** -- Crop rect always stays within rotated image bounds
- **Save and restore** -- `CropSettings` lets you restore previous crop state when re-editing
- **HDR/HEIF support** -- Automatically normalizes iOS HDR images via `flutter_image_compress`
- **Customizable theming** -- Full color, text, and label customization via `CropperThemeData`
- **Platform-adaptive overlay** -- Blur overlay on iOS/macOS, solid overlay on other platforms

## Installation

```yaml
dependencies:
  cropme: ^0.0.1
```

## Usage

### Basic

```dart
import 'package:cropme/cropme.dart';

final result = await ImageCropper.show(
  context: context,
  imageBytes: imageBytes, // Uint8List
);

if (result != null) {
  final croppedBytes = result.bytes; // Uint8List
  final settings = result.settings; // Save for re-editing later
}
```

### With Custom Theme

```dart
final result = await ImageCropper.show(
  context: context,
  imageBytes: imageBytes,
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
final savedSettings = previousResult.settings;

final result = await ImageCropper.show(
  context: context,
  imageBytes: imageBytes,
  initialSettings: savedSettings,
);
```

### Using as a Widget

```dart
ImageCropper(
  imageBytes: imageBytes,
  initialSettings: savedSettings,
  theme: CropperThemeData(accentColor: Colors.orange),
)
```

## API Reference

### ImageCropper

| Property | Type | Default | Description |
|---|---|---|---|
| `imageBytes` | `Uint8List` | required | Source image bytes to crop |
| `initialSettings` | `CropSettings?` | `null` | Restore previous crop state |
| `theme` | `CropperThemeData` | Default dark | Theme configuration |

### ImageCropper.show()

| Parameter | Type | Default | Description |
|---|---|---|---|
| `context` | `BuildContext` | required | Build context for navigation |
| `imageBytes` | `Uint8List` | required | Source image bytes |
| `initialSettings` | `CropSettings?` | `null` | Restore previous crop state |
| `theme` | `CropperThemeData` | Default dark | Theme configuration |

Returns `Future<CropResult?>`. Returns `null` if the user cancels.

### CropResult

| Property | Type | Description |
|---|---|---|
| `bytes` | `Uint8List` | The cropped image bytes |
| `settings` | `CropSettings` | Settings used, save for re-editing |

### CropperThemeData

| Property | Type | Default | Description |
|---|---|---|---|
| `backgroundColor` | `Color` | `#000000` | Scaffold background |
| `overlayColor` | `Color` | `#99000000` | Area outside crop rect |
| `overlayBlurSigma` | `double` | `20.0` | Blur intensity for the overlay. Set to 0 to disable |
| `blurEnabledPlatforms` | `Set<TargetPlatform>` | iOS, macOS | Platforms where blur is enabled |
| `gridLineColor` | `Color` | `#33FFFFFF` | Rule-of-thirds grid lines |
| `accentColor` | `Color` | `#FFC107` | Rotation indicator and highlights |
| `buttonBackgroundColor` | `Color` | `#2C2C2E` | Button background |
| `buttonTextColor` | `Color` | `#FFFFFF` | Button text |
| `buttonTextStyle` | `TextStyle` | 14sp, w500, white | Button label style |
| `appBarForegroundColor` | `Color` | `#FFFFFF` | App bar icon/text color |
| `closeIcon` | `IconData` | `CupertinoIcons.xmark` | Close button icon |
| `loadingIndicatorColor` | `Color` | `#FFFFFF` | Loading spinner color |
| `progressIndicatorBackgroundColor` | `Color` | `#000000` | Progress indicator track |
| `cropButtonColor` | `Color` | `#FFFFFF` | Crop button background |
| `cropButtonTextColor` | `Color` | `#000000` | Crop button text |
| `cropCornerRadius` | `double` | `12.0` | Crop rect corner radius |
| `resetLabel` | `String` | `'Reset'` | Reset button text |
| `cropLabel` | `String` | `'Crop & Save'` | Crop button text |

### CropSettings

Serializable model for saving and restoring crop state. Supports `toMap()` and `fromMap()` for persistence.

| Property | Type | Description |
|---|---|---|
| `scale` | `double` | Zoom level (1.0 = original) |
| `offsetX` | `double` | X offset of the transformation |
| `offsetY` | `double` | Y offset of the transformation |
| `rotation` | `double` | Rotation angle in radians |
| `aspectRatio` | `double?` | Fixed aspect ratio, `null` for free-form |
| `cropRectLeft` | `double` | Crop rect left position |
| `cropRectTop` | `double` | Crop rect top position |
| `cropRectWidth` | `double` | Crop rect width |
| `cropRectHeight` | `double` | Crop rect height |

## Requirements

- Flutter 3.32+
- Dart 3.8+

## License

MIT License -- see [LICENSE](LICENSE) for details.
