import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// InterTaxi Custom Text Field
/// Premium, reusable input field with dark theme support
class CustomTextField extends StatefulWidget {
  final String label;
  final String? hintText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool enabled;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    required this.label,
    this.hintText,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.controller,
    this.enabled = true,
    this.maxLines = 1,
    this.inputFormatters,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _borderAnimation;
  bool _isFocused = false;
  bool _hasValue = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.fieldFocusAnimation,
      vsync: this,
    );

    _borderAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppConstants.fieldFocusCurve,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    setState(() {
      _isFocused = focused;
    });

    if (focused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: TextStyle(
            fontSize: AppConstants.fieldLabelSize,
            fontWeight: FontWeight.w500,
            color: _isFocused ? AppColors.primaryBlue : AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        // Text Field
        Focus(
          onFocusChange: _handleFocusChange,
          child: AnimatedBuilder(
            animation: _borderAnimation,
            builder: (context, child) {
              return SizedBox(
                height: AppConstants.fieldHeight,
                child: TextFormField(
                  controller: widget.controller,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  obscureText: widget.obscureText,
                  validator: widget.validator,
                  onChanged: (value) {
                    setState(() {
                      _hasValue = value.isNotEmpty;
                    });
                    widget.onChanged?.call(value);
                  },
                  enabled: widget.enabled,
                  maxLines: widget.maxLines,
                  inputFormatters: widget.inputFormatters,
                  style: TextStyle(
                    fontSize: AppConstants.fieldTextSize,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontSize: AppConstants.fieldTextSize,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      letterSpacing: 0.2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.fieldBorderRadius,
                      ),
                      borderSide: BorderSide(
                        color: _isFocused
                            ? AppColors.primaryBlue
                            : AppColors.cardBorder,
                        width: AppConstants.fieldBorderWidth,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.fieldBorderRadius,
                      ),
                      borderSide: BorderSide(
                        color: AppColors.cardBorder,
                        width: AppConstants.fieldBorderWidth,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.fieldBorderRadius,
                      ),
                      borderSide: BorderSide(
                        color: AppColors.primaryBlue,
                        width: AppConstants.fieldBorderWidth,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
