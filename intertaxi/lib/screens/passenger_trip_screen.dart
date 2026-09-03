import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../widgets/custom_button.dart';
import 'location_selection_screen.dart';

/// InterTaxi Passenger Trip Selection Screen
/// Premium trip booking screen in Tajik language
class PassengerTripScreen extends StatefulWidget {
  final String passengerName;
  final String passengerPhone;

  const PassengerTripScreen({
    super.key,
    required this.passengerName,
    required this.passengerPhone,
  });

  @override
  State<PassengerTripScreen> createState() => _PassengerTripScreenState();
}

class _PassengerTripScreenState extends State<PassengerTripScreen> {
  String? _selectedStartLocation;
  String? _selectedDestination;
  bool _isLoading = false;
  bool _isStartCardExpanded = false;
  bool _isDestinationCardExpanded = false;

  final List<String> _startLocations = ['Кӯлоб', 'Душанбе', 'Восеъ'];

  final List<String> _destinationLocations = ['Кӯлоб', 'Душанбе', 'Восеъ'];

  void _handleLocationSelect(String type, String location) {
    setState(() {
      if (type == 'start') {
        _selectedStartLocation = location;
        _isStartCardExpanded = false;
      } else {
        _selectedDestination = location;
        _isDestinationCardExpanded = false;
      }
    });
  }

  void _handleSearch() {
    if (_selectedStartLocation == null || _selectedDestination == null) return;

    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Navigate to next screen
        // TODO: Navigate to driver selection screen
        print('Search: $_selectedStartLocation to $_selectedDestination');
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
                // Welcome Title
                Text(
                  'Хуш омадед, мусофир!',
                  style: TextStyle(
                    fontSize: AppConstants.welcomeTitleSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                // Subtitle
                Text(
                  'Биёед саёҳати худро оғоз кунем',
                  style: TextStyle(
                    fontSize: AppConstants.welcomeSubtitleSize,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                // Starting Location Card
                _buildLocationCard(
                  title: 'Аз куҷо меравед?',
                  placeholder: 'Ҷойи оғозро интихоб кунед',
                  selectedLocation: _selectedStartLocation,
                  icon: Icons.trip_origin_rounded,
                  onTap: () => _openLocationScreen('start'),
                ),
                const SizedBox(height: 16),
                // Destination Card
                _buildLocationCard(
                  title: 'Ба куҷо рафтан мехоҳед?',
                  placeholder: 'Макони таъинотро интихоб кунед',
                  selectedLocation: _selectedDestination,
                  icon: Icons.location_on_rounded,
                  onTap: () => _openLocationScreen('destination'),
                ),
                const SizedBox(height: 40),
                // Search Button
                CustomButton(
                  text: 'Ҷустуҷӯи мошин',
                  onPressed: _handleSearch,
                  isLoading: _isLoading,
                  enabled:
                      _selectedStartLocation != null &&
                      _selectedDestination != null &&
                      !_isLoading,
                ),
                const SizedBox(height: 24),
                // Helper Text
                Center(
                  child: Text(
                    'Нуқтаҳои дигарро низ интихоб карда метавонед',
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

  void _openLocationScreen(String type) {
    final locations = type == 'start' ? _startLocations : _destinationLocations;
    final selected = type == 'start'
        ? _selectedStartLocation
        : _selectedDestination;
    final title = type == 'start'
        ? 'Аз куҷо меравед?'
        : 'Ба куҷо рафтан мехоҳед?';

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LocationSelectionScreen(
              title: title,
              locations: locations,
              selectedLocation: selected,
              onSelect: (location) => _handleLocationSelect(type, location),
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required String placeholder,
    required String? selectedLocation,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedLocation != null
              ? AppColors.primaryBlue
              : AppColors.cardBorder,
          width: selectedLocation != null ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Icon with professional styling
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedLocation != null
                          ? AppColors.primaryBlue
                          : AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: selectedLocation != null
                          ? AppColors.white
                          : AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title and selected location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedLocation ?? placeholder,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: selectedLocation != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selectedLocation != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow icon
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
