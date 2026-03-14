import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_app/core/theme/app_theme.dart';

// Toast Controller Provider - uses SnackBar
final toastControllerProvider = Provider<ToastController>((ref) {
  return ToastController();
});

class ToastController {
  void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final color = _getColor(type);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void showSuccess(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  void showError(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }

  Color _getColor(ToastType type) {
    switch (type) {
      case ToastType.success:
        return AppTheme.accentGreen;
      case ToastType.error:
        return AppTheme.accentRed;
      case ToastType.info:
        return AppTheme.primaryColor;
    }
  }
}

enum ToastType {
  info,
  success,
  error,
}