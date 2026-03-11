import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:cropme/cropme.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const CropmeExampleApp());
}

class CropmeExampleApp extends StatelessWidget {
  const CropmeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Cropme',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.systemYellow,
        scaffoldBackgroundColor: Color(0xFF000000),
        barBackgroundColor: Color(0x00000000),
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            color: CupertinoColors.white,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Uint8List? _croppedBytes;
  CropSettings? _lastSettings;
  Uint8List? _originalBytes;
  final _picker = ImagePicker();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCrop() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    _originalBytes = await picked.readAsBytes();

    if (!mounted) return;

    final result = await ImageCropper.show(
      context: context,
      imageBytes: _originalBytes!,
      theme: const CropperThemeData(
        accentColor: Color(0xFFFFC107),
        cropCornerRadius: 16.0,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _croppedBytes = result.bytes;
        _lastSettings = result.settings;
      });
    }
  }

  Future<void> _recrop() async {
    if (_originalBytes == null) return;

    final result = await ImageCropper.show(
      context: context,
      imageBytes: _originalBytes!,
      initialSettings: _lastSettings,
    );

    if (result != null && mounted) {
      setState(() {
        _croppedBytes = result.bytes;
        _lastSettings = result.settings;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    return CupertinoPageScaffold(
      child: _croppedBytes != null
          ? _buildResultView(topPadding)
          : _buildEmptyState(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppleButton(
            onPressed: _pickAndCrop,
            icon: CupertinoIcons.photo,
            label: 'Choose Photo',
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(double topPadding) {
    final rotation = _lastSettings?.rotation ?? 0;
    final degrees = (rotation * 180 / 3.14159).toStringAsFixed(1);

    return SafeArea(
      child: Column(
        children: [
          // Custom nav bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Result',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: CupertinoColors.white,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _recrop,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: ShapeDecoration(
                      color: CupertinoColors.systemGrey6.darkColor
                          .withValues(alpha: 0.5),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.pencil,
                          size: 16,
                          color: CupertinoColors.systemYellow,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.systemYellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cropped image
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: Hero(
                  tag: 'cropped_image',
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: ShapeDecoration(
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        shadows: [
                          BoxShadow(
                            color: CupertinoColors.systemYellow
                                .withValues(alpha: 0.08),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 340,
                          maxHeight: 440,
                        ),
                        child: Image.memory(
                          _croppedBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Info chips
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _InfoChip(
                  icon: CupertinoIcons.rotate_right,
                  label: '$degrees°',
                ),
              ],
            ),
          ),

          // Bottom action
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
            child: _AppleButton(
              onPressed: _pickAndCrop,
              icon: CupertinoIcons.photo,
              label: 'Choose Another',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Apple-style button ──────────────────────────────────────────────────────

class _AppleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _AppleButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  State<_AppleButton> createState() => _AppleButtonState();
}

class _AppleButtonState extends State<_AppleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: ShapeDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.12),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: CupertinoColors.white.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 20,
                      color: CupertinoColors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Info chip ───────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: ShapeDecoration(
        color: CupertinoColors.systemGrey6.darkColor.withValues(alpha: 0.4),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}
