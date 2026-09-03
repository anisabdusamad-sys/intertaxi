import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// InterTaxi Custom Button
/// Simple, clean button widget
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final Color? backgroundColor;
  final Color? textColor;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && onPressed != null && !isLoading;

    return GestureDetector(
      onTap: isActive ? onPressed : null,
      child: Container(
        height: AppConstants.buttonHeight,
        decoration: BoxDecoration(
          color: isActive
              ? backgroundColor ?? AppColors.primaryBlue
              : AppColors.gray300,
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      textColor ?? AppColors.white,
                    ),
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: AppConstants.buttonTextSize,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? textColor ?? AppColors.white
                        : AppColors.gray400,
                  ),
                ),
        ),
      ),
    );
  }
}
