import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'overlay_toast_util.dart';

class ToastHelper {
  static void showSnackBarToast(
    BuildContext context,
    SnackBar snackBar,
  ) {
    final contentWidget = snackBar.content;
    String message = '';
    Color textColor = Colors.white;

    if (contentWidget is Text) {
      final text = contentWidget;
      message = text.data ?? text.textSpan?.toPlainText() ?? '';
      if (text.style?.color != null) {
        textColor = text.style!.color!;
      }
    } else {
      message = contentWidget.toString();
    }

    final backgroundColor =
        snackBar.backgroundColor ?? AppColors.darkBlue.withOpacity(0.95);

    IconData? icon;
    if (backgroundColor == AppColors.error || backgroundColor == Colors.red) {
      icon = Icons.error;
    } else if (backgroundColor == AppColors.success ||
        backgroundColor == Colors.green) {
      icon = Icons.check_circle;
    }

    OverlayToastUtil.showToast(
      context,
      message: message.isEmpty ? 'Action completed' : message,
      backgroundColor: backgroundColor,
      textColor: textColor,
      duration: snackBar.duration,
      icon: icon,
      iconColor: textColor,
    );
  }

  static void showInfo(BuildContext context, String message) {
    OverlayToastUtil.showToast(
      context,
      message: message,
      backgroundColor: AppColors.info,
      icon: Icons.info_outline,
      iconColor: Colors.white,
    );
  }
}


