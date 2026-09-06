import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/driver_ride_model.dart';

/// Premium compact trip card for the passenger search results.
///
/// Flat, modern design showing ONLY:
///   • Ному Насаб (driver name)
///   • Рақами телефон (driver phone)
///   • Ҷои нишаст (available seats)
///   • Масир: аз куҷо то куҷо (route: from → to)
/// plus a compact details action that opens the full trip details.
class DriverRideCard extends StatelessWidget {
  final DriverRide ride;
  final String searchFrom;
  final String searchTo;

  /// Called when the card or the details action is tapped.
  final VoidCallback? onTap;

  const DriverRideCard({
    super.key,
    required this.ride,
    required this.searchFrom,
    required this.searchTo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final from = ride.route.isNotEmpty ? ride.route.first : searchFrom;
    final to = ride.route.length > 1 ? ride.route.last : searchTo;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8FF)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDriverRow(),
                const SizedBox(height: 5),
                _buildRouteRow(from, to),
                const SizedBox(height: 5),
                _buildScheduleRow(),
                const SizedBox(height: 4),
                _buildSeatsRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Driver avatar + name (Ному Насаб) + phone number (Рақами телефон).
  Widget _buildDriverRow() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 18,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.driverName.isEmpty ? 'Ронанда' : ride.driverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    size: 11,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      ride.driverPhone.isEmpty ? '—' : ride.driverPhone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Route row: Масир — аз куҷо то куҷо (origin → destination).
  Widget _buildRouteRow(String from, String to) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        Container(width: 2, height: 10, color: AppColors.gray300),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Масир: аз $from то $to',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// Available seats (Ҷои нишаст) + the "Подробно" action button.
  Widget _buildScheduleRow() {
    return Row(
      children: [
        const Icon(
          Icons.schedule_rounded,
          size: 13,
          color: AppColors.primaryBlue,
        ),
        const SizedBox(width: 4),
        Text(
          ride.departureLabel,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          ride.durationLabel,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatsRow() {
    return Row(
      children: [
        const Icon(
          Icons.event_seat_rounded,
          size: 13,
          color: AppColors.primaryBlue,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Ҷои нишаст: ${ride.availableSeats}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${ride.fullRoutePrice} сомонӣ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onTap,
          tooltip: 'Кушодани маълумоти сафар',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 24, height: 24),
          style: IconButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primaryBlue,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 13),
        ),
      ],
    );
  }
}
