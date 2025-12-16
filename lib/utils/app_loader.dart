import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;

  const AppLoader({
    super.key,
    this.size = 32,
    this.strokeWidth = 3,
    this.color,
    this.backgroundColor,
  });

  // Static overlay entry for show/hide functionality
  static OverlayEntry? _overlayEntry;

  /// Show a loading overlay
  static void show(BuildContext context) {
    if (_overlayEntry != null) return; // Already showing

    _overlayEntry = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.3),
        child: const Center(
          child: AppLoader(size: 48, strokeWidth: 4),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hide the loading overlay
  static void hide(BuildContext context) {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.info;
    final effectiveBackground = backgroundColor ?? effectiveColor.withOpacity(0.15);

    return SizedBox(
      height: size,
      width: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveColor),
        backgroundColor: effectiveBackground,
      ),
    );
  }
}


