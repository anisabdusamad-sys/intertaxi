import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// InterTaxi Premium Logo Widget
/// Minimalist, clean design with smooth animations
class InterTaxiLogo extends StatelessWidget {
  final double size;
  final bool showTagline;

  const InterTaxiLogo({
    super.key,
    this.size = AppConstants.logoSize,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo icon with taxi symbol
        _buildLogoIcon(),
        const SizedBox(height: AppConstants.logoTextSpacing),
        // Brand name
        _buildBrandName(),
        if (showTagline) ...[const SizedBox(height: 8), _buildTagline()],
      ],
    );
  }

  Widget _buildLogoIcon() {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(
        Icons.local_taxi_rounded,
        size: size * 0.5,
        color: AppColors.white,
      ),
    );
  }

  Widget _buildBrandName() {
    return Text(
      'InterTaxi',
      style: TextStyle(
        fontSize: AppConstants.logoFontSize,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.2,
      ),
    );
  }

  Widget _buildTagline() {
    return Text(
      'Your ride, your way',
      style: TextStyle(
        fontSize: AppConstants.taglineFontSize,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        letterSpacing: 0.2,
      ),
    );
  }
}
