import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// InterTaxi Location Selection Screen
/// Simple screen for selecting cities
class LocationSelectionScreen extends StatefulWidget {
  final String title;
  final List<String> locations;
  final String? selectedLocation;
  final ValueChanged<String> onSelect;

  const LocationSelectionScreen({
    super.key,
    required this.title,
    required this.locations,
    this.selectedLocation,
    required this.onSelect,
  });

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Title
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              // Location List
              Expanded(
                child: ListView.builder(
                  itemCount: widget.locations.length,
                  itemBuilder: (context, index) {
                    final location = widget.locations[index];
                    final isSelected = widget.selectedLocation == location;

                    return GestureDetector(
                      onTap: () {
                        widget.onSelect(location);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.cardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Location icon with background
                            Container(
                              width: 40,
                              height: 40,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.white.withValues(alpha: 0.2)
                                    : AppColors.lightBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 20,
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Location name
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            // Check icon
                            if (isSelected)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primaryBlue,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
