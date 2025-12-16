import 'dart:async';

import 'package:flutter/material.dart';

class OverlayToastUtil {
  static OverlayEntry? _currentOverlay;

  /// 🔹 Show a simple toast with optional customization
  static void showToast(
    BuildContext context, {
    required String message,
    Color backgroundColor = Colors.black87,
    Color textColor = Colors.white,
    double bottomOffset = 100,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    Color? iconColor,
  }) {
    _currentOverlay?.remove();
    _currentOverlay = null;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedToast(
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        bottomOffset: bottomOffset,
        icon: icon,
        iconColor: iconColor,
      ),
    );

    overlay.insert(overlayEntry);
    _currentOverlay = overlayEntry;

    Timer(duration, () {
      _currentOverlay?.remove();
      _currentOverlay = null;
    });
  }

  /// ✅ Success toast
  static void showSuccess(BuildContext context, String message) {
    showToast(
      context,
      message: message,
      backgroundColor: const Color(0xFF43A047),
      icon: Icons.check_circle,
      iconColor: Colors.white,
    );
  }

  /// ❌ Error toast
  static void showError(BuildContext context, String message) {
    showToast(
      context,
      message: message,
      backgroundColor: const Color(0xFFE53935),
      icon: Icons.error,
      iconColor: Colors.white,
    );
  }
}

class _AnimatedToast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final double bottomOffset;
  final IconData? icon;
  final Color? iconColor;

  const _AnimatedToast({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.bottomOffset,
    this.icon,
    this.iconColor,
  });

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.bottomOffset,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null)
                  Icon(
                    widget.icon,
                    color: widget.iconColor ?? widget.textColor,
                  ),
                if (widget.icon != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


