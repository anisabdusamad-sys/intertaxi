import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// InterTaxi Role Selection Card
/// Premium selection card with smooth animations
enum UserRole { passenger, driver }

class RoleSelectionCard extends StatefulWidget {
  final UserRole role;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final ValueChanged<UserRole>? onTap;

  const RoleSelectionCard({
    super.key,
    required this.role,
    required this.title,
    required this.description,
    required this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<RoleSelectionCard> createState() => _RoleSelectionCardState();
}

class _RoleSelectionCardState extends State<RoleSelectionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppConstants.cardSelectionAnimation,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppConstants.cardSelectionCurve,
      ),
    );

    _borderAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppConstants.cardSelectionCurve,
      ),
    );

    if (widget.isSelected) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(RoleSelectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call(widget.role);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: AppConstants.roleCardHeight,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.cardSelected
                    : AppColors.white,
                borderRadius: BorderRadius.circular(
                  AppConstants.roleCardBorderRadius,
                ),
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.primaryBlue
                      : AppColors.cardBorder,
                  width: widget.isSelected ? 2.0 : 1.0,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  // Selection indicator
                  if (widget.isSelected)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon with professional styling
                        Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.isSelected
                                ? AppColors.primaryBlue
                                : AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            widget.icon,
                            size: 32,
                            color: widget.isSelected
                                ? AppColors.white
                                : AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Title
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: AppConstants.roleCardTitleSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Description
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: AppConstants.roleCardDescriptionSize,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.2,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
