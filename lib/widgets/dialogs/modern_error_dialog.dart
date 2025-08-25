import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../constants/app_colors.dart';

/// Modern error dialog that matches the app's design system
class ModernErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final ErrorType type;
  final VoidCallback? onRetry;
  final String? retryButtonText;
  final String? dismissButtonText;

  const ModernErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.type = ErrorType.general,
    this.onRetry,
    this.retryButtonText,
    this.dismissButtonText,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = _getColorScheme();
    
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon and Title
            _buildHeader(colorScheme),
            
            const SizedBox(height: 16),
            
            // Message
            _buildMessage(),
            
            const SizedBox(height: 24),
            
            // Action buttons
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ErrorColorScheme colorScheme) {
    return Column(
      children: [
        // Error icon with animated container
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  colorScheme.icon,
                  color: colorScheme.iconColor,
                  size: 28,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Title
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (onRetry != null) {
      // Two button layout: Retry + Dismiss
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.grey300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                dismissButtonText ?? 'Dismiss',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getColorScheme().primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                retryButtonText ?? 'Try Again',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Single button layout: Dismiss only
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.bgPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            dismissButtonText ?? 'OK',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  ErrorColorScheme _getColorScheme() {
    switch (type) {
      case ErrorType.validation:
        return ErrorColorScheme(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
          iconColor: Colors.orange,
          primaryColor: Colors.orange,
          icon: LucideIcons.alertTriangle,
        );
      case ErrorType.network:
        return ErrorColorScheme(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          iconColor: Colors.blue,
          primaryColor: Colors.blue,
          icon: LucideIcons.wifi,
        );
      case ErrorType.permission:
        return ErrorColorScheme(
          backgroundColor: Colors.purple.withValues(alpha: 0.1),
          iconColor: Colors.purple,
          primaryColor: Colors.purple,
          icon: LucideIcons.lock,
        );
      case ErrorType.general:
      default:
        return ErrorColorScheme(
          backgroundColor: Colors.red.withValues(alpha: 0.1),
          iconColor: Colors.red,
          primaryColor: Colors.red,
          icon: LucideIcons.alertCircle,
        );
    }
  }
}

/// Error types for different styling
enum ErrorType {
  general,
  validation,
  network,
  permission,
}

/// Color scheme for different error types
class ErrorColorScheme {
  final Color backgroundColor;
  final Color iconColor;
  final Color primaryColor;
  final IconData icon;

  const ErrorColorScheme({
    required this.backgroundColor,
    required this.iconColor,
    required this.primaryColor,
    required this.icon,
  });
}

/// Helper function to show modern error dialog
Future<void> showModernErrorDialog({
  required BuildContext context,
  required String title,
  required String message,
  ErrorType type = ErrorType.general,
  VoidCallback? onRetry,
  String? retryButtonText,
  String? dismissButtonText,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => ModernErrorDialog(
      title: title,
      message: message,
      type: type,
      onRetry: onRetry,
      retryButtonText: retryButtonText,
      dismissButtonText: dismissButtonText,
    ),
  );
}