import 'package:flutter/material.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../widgets/intertaxi_logo.dart';
import '../widgets/loading_indicator.dart';
import 'registration_screen.dart';

/// InterTaxi Premium Splash Screen
/// Fast, minimalist, and elegant loading experience
class SplashScreen extends StatefulWidget {
  final VoidCallback? onInitializationComplete;
  final Duration minDisplayTime;

  const SplashScreen({
    super.key,
    this.onInitializationComplete,
    this.minDisplayTime = AppConstants.splashMinDisplayTime,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isInitialized = false;
  bool _canNavigate = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _setupAnimations();
    _startInitialization();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: AppConstants.splashAnimationDuration,
      vsync: this,
    );

    // Fade animation for logo
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppConstants.logoFadeCurve,
      ),
    );

    // Scale animation for logo
    _scaleAnimation =
        Tween<double>(
          begin: AppConstants.logoScaleStart,
          end: AppConstants.logoScaleEnd,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppConstants.logoScaleCurve,
          ),
        );

    // Start animations immediately
    _animationController.forward();
  }

  Future<void> _startInitialization() async {
    // Simulate app initialization (replace with actual initialization logic)
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });

      // Check if minimum display time has passed
      _checkNavigation();
    }
  }

  void _checkNavigation() {
    if (!_isInitialized || _canNavigate) return;

    final elapsed = DateTime.now().difference(_startTime!);
    final remainingTime = widget.minDisplayTime - elapsed;

    if (remainingTime <= Duration.zero) {
      _navigateToHome();
    } else {
      Future.delayed(remainingTime, _navigateToHome);
    }
  }

  void _navigateToHome() {
    if (_canNavigate || !mounted) return;

    setState(() {
      _canNavigate = true;
    });

    // Navigate to registration screen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const RegistrationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    // Also call the callback if provided
    widget.onInitializationComplete?.call();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // InterTaxi Logo
                      const InterTaxiLogo(showTagline: true),
                      const SizedBox(height: AppConstants.loadingTopSpacing),
                      // Loading Indicator
                      const InterTaxiLoadingIndicator(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
