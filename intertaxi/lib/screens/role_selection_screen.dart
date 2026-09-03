import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../widgets/role_selection_card.dart';
import '../widgets/custom_button.dart';
import 'socket_passenger_screen.dart';
import 'socket_driver_screen.dart';
import 'socket_launcher_screen.dart';

/// InterTaxi User Role Selection Screen
/// Premium dark theme role selection in Tajik language
class RoleSelectionScreen extends StatefulWidget {
  final String passengerName;
  final String passengerPhone;

  const RoleSelectionScreen({
    super.key,
    required this.passengerName,
    required this.passengerPhone,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;
  bool _isLoading = false;

  void _handleRoleSelection(UserRole role) {
    setState(() {
      _selectedRole = role;
    });
  }

  void _handleContinue() {
    if (_selectedRole == null) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate API call or navigation
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Navigate to appropriate screen based on role
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (_selectedRole == UserRole.passenger) {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      SocketPassengerScreen(
                        passengerName: widget.passengerName,
                        passengerPhone: widget.passengerPhone,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            } else {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      SocketDriverScreen(
                        driverName: widget.passengerName,
                        driverPhone: widget.passengerPhone,
                        driverCar: 'Toyota Camry (White)',
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                // Title
                Text(
                  'Шумо кӣ ҳастед?',
                  style: TextStyle(
                    fontSize: AppConstants.roleTitleSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 32),
                // Role Cards
                Column(
                  children: [
                    // Passenger Card
                    RoleSelectionCard(
                      role: UserRole.passenger,
                      title: 'Мусофир',
                      description: 'Ман мехоҳам бо таксӣ сафар кунам',
                      icon: Icons.person,
                      isSelected: _selectedRole == UserRole.passenger,
                      onTap: _handleRoleSelection,
                    ),
                    const SizedBox(height: AppConstants.cardSpacing),
                    // Driver Card
                    RoleSelectionCard(
                      role: UserRole.driver,
                      title: 'Ронанда',
                      description: 'Ман мехоҳам ҳамчун ронанда кор кунам',
                      icon: Icons.directions_car,
                      isSelected: _selectedRole == UserRole.driver,
                      onTap: _handleRoleSelection,
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Continue Button
                CustomButton(
                  text: 'Идома додан',
                  onPressed: _handleContinue,
                  isLoading: _isLoading,
                  enabled: _selectedRole != null && !_isLoading,
                ),
                const SizedBox(height: 24),
                // Divider with "OR" text
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'LIVE DEMO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 16),
                // Socket.IO Live Demo Button
                CustomButton(
                  text: 'Real-Time Socket Demo',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SocketLauncherScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Helper Text
                Center(
                  child: Text(
                    'Шумо метавонед баъдтар навнависӣ кунед',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
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


