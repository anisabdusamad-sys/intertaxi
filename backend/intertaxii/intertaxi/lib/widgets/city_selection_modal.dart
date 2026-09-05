import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// The 10 Tajik cities / districts available for route selection.
///
/// IMPORTANT: keep this list identical to the driver's location list
/// (main.dart `_allLocations` and create_order_screen `_locations`) —
/// the passenger's search matches driver announcements by exact city
/// name, so any mismatch here silently hides driver trips.
const List<String> tajikCities = [
  'Кӯлоб',
  'Душанбе',
  'Восеъ',
  'Хуҷанд',
  'Бухоро',
  'Самарқанд',
  'Файзобод',
  'Турсунзода',
  'Панҷакент',
  'Истаравшан',
];

/// Shows a Modal Bottom Sheet with the list of Tajik cities.
/// Resolves with the selected city name, or null when dismissed.
Future<String?> showCitySelectionSheet({
  required BuildContext context,
  required String title,
  List<String> cities = tajikCities,
  String? selectedCity,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CitySelectionSheet(
      title: title,
      cities: cities,
      selectedCity: selectedCity,
    ),
  );
}

/// Premium accent used across the city selection sheet.
const Color _kPrimaryAccent = Color(0xFF1E56EC);

class _CitySelectionSheet extends StatefulWidget {
  final String title;
  final List<String> cities;
  final String? selectedCity;

  const _CitySelectionSheet({
    required this.title,
    required this.cities,
    this.selectedCity,
  });

  @override
  State<_CitySelectionSheet> createState() => _CitySelectionSheetState();
}

class _CitySelectionSheetState extends State<_CitySelectionSheet> {
  String _query = '';

  /// Cities filtered by the search query (case-insensitive).
  List<String> get _filteredCities {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.cities;
    return widget.cities
        .where((city) => city.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        // Keep the sheet above the keyboard while typing in the search field.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header: accent bar + bold title + subtitle + close button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: _kPrimaryAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Шаҳр ё ноҳияро интихоб кунед',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick dismiss
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.grey[600],
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Real-time search / filter field
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.screenPadding,
              ),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                cursorColor: _kPrimaryAccent,
                decoration: InputDecoration(
                  hintText: 'Ҷустуҷӯи шаҳр...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _kPrimaryAccent,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: _kPrimaryAccent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(child: _buildCitiesList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildCitiesList(BuildContext context) {
    final filteredCities = _filteredCities;

    // Empty state when the search query matches nothing.
    if (filteredCities.isEmpty) {
      return ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(
          left: AppConstants.screenPadding,
          right: AppConstants.screenPadding,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'Шаҳр ёфт нашуд',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.only(
        left: AppConstants.screenPadding,
        right: AppConstants.screenPadding,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      itemCount: filteredCities.length,
      itemBuilder: (context, index) {
        final city = filteredCities[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CityTile(
            city: city,
            isSelected: city == widget.selectedCity,
            onTap: () => Navigator.of(context).pop(city),
          ),
        );
      },
    );
  }
}

/// Premium city tile: elevated rounded card with a circular pin badge,
/// active selection state, ripple and slight scale press feedback.
class _CityTile extends StatefulWidget {
  final String city;
  final bool isSelected;
  final VoidCallback onTap;

  const _CityTile({
    required this.city,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CityTile> createState() => _CityTileState();
}

class _CityTileState extends State<_CityTile> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    return AnimatedScale(
      scale: _scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _scale = 0.97),
          onTapUp: (_) => setState(() => _scale = 1.0),
          onTapCancel: () => setState(() => _scale = 1.0),
          borderRadius: BorderRadius.circular(16),
          splashColor: _kPrimaryAccent.withValues(alpha: 0.08),
          highlightColor: _kPrimaryAccent.withValues(alpha: 0.05),
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected
                  ? _kPrimaryAccent.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _kPrimaryAccent : Colors.grey[200]!,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Vibrant circular pin badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _kPrimaryAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: _kPrimaryAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.city,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? _kPrimaryAccent
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: _kPrimaryAccent,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

