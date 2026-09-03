import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/driver_ride_model.dart';

/// Card representing one matching driver ride in the search results.
/// Shows: driver name, car model + colored avatar, available seats,
/// price per seat for the requested segment, departure time and route.
class DriverRideCard extends StatelessWidget {
  final DriverRide ride;
  final String searchFrom;
  final String searchTo;
  final VoidCallback? onTap;

  const DriverRideCard({
    super.key,
    required this.ride,
    required this.searchFrom,
    required this.searchTo,
    this.onTap,
  });

  static const Map<String, Color> _carColorMap = {
    'сафед': Color(0xFFE8EDF5),
    'сиёҳ': Color(0xFF2B2F3A),
    'нуқрагӣ': Color(0xFFB8C0CC),
    'кабуд': Color(0xFF0066FF),
    'сурх': Color(0xFFE53935),
    'ҳафтранг': Color(0xFFF5A623),
  };

  Color get _avatarColor =>
      _carColorMap[ride.carColor] ?? AppColors.primaryBlue;

  @override
  Widget build(BuildContext context) {
    final segmentPrice = ride.priceForSegment(searchFrom, searchTo);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(segmentPrice),
                const SizedBox(height: 14),
                _buildRouteRow(),
                const SizedBox(height: 12),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Driver name + car info + segment price per seat.
  Widget _buildHeader(int segmentPrice) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _avatarColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.directions_car_rounded,
            size: 26,
            color: _avatarColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.driverName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${ride.carModel} • ${ride.carColor} • ${ride.carPlate}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$segmentPrice с.',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'барои ҷой',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Requested segment with an indirect-match badge when the driver
  /// covers the segment via intermediate stops.
  Widget _buildRouteRow() {
    final isDirect = ride.isExactMatch(searchFrom, searchTo);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        Container(width: 2, height: 14, color: AppColors.gray300),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$searchFrom → $searchTo',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!isDirect)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'тавассути дигар шаҳрҳо',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
      ],
    );
  }

  /// Departure time (with live countdown) and available seats.
  Widget _buildFooter() {
    return Row(
      children: [
        const Icon(
          Icons.schedule_rounded,
          size: 16,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${ride.departureLabel} (${ride.countdownLabel})',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(
          Icons.event_seat_rounded,
          size: 16,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          '${ride.availableSeats} ҷойи холӣ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
