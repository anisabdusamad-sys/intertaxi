import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../services/socket_service.dart';

/// InterTaxi Trip Detail Screen (Подробно).
///
/// Shows the FULL information about a single trip: from/to locations,
/// available seats, price, departure time and driver details (name, phone).
/// Opened from the compact trip card in the passenger list.
class TripDetailScreen extends StatefulWidget {
  /// Raw trip map exactly as delivered by the backend / socket events.
  final Map<String, dynamic> trip;

  final String passengerName;
  final String passengerPhone;

  const TripDetailScreen({
    super.key,
    required this.trip,
    this.passengerName = '',
    this.passengerPhone = '',
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  bool _booking = false;

  // --- Field accessors with safe fallbacks ---------------------------------

  String get _id => widget.trip['id']?.toString() ?? '';
  String get _from => widget.trip['from_location']?.toString() ?? '—';
  String get _to => widget.trip['to_location']?.toString() ?? '—';
  String get _price => widget.trip['price']?.toString() ?? '0';
  String get _seats => widget.trip['available_seats']?.toString() ?? '0';
  String get _departure {
    final raw = widget.trip['departure_time']?.toString() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = (parsed.year % 100).toString().padLeft(2, '0');
    return '$hour:$minute $day.$month.$year';
  }

  int get _durationMinutes =>
      int.tryParse(widget.trip['duration_minutes']?.toString() ?? '') ?? 0;
  String get _carBrand => widget.trip['car_brand']?.toString() ?? '';
  String get _carModel => widget.trip['car_model']?.toString() ?? '';
  String get _carColor => widget.trip['car_color']?.toString() ?? '';
  String get _carPlate => widget.trip['car_plate']?.toString() ?? '';
  String get _driverName => widget.trip['driver_name']?.toString() ?? '';
  String get _driverPhone => widget.trip['driver_phone']?.toString() ?? '';
  bool get _isActive => widget.trip['status']?.toString() == 'active';
  int get _seatsInt => int.tryParse(_seats) ?? 0;
  bool get _bookable => _isActive && _seatsInt > 0;

  // --- Actions --------------------------------------------------------------

  void _bookTrip() {
    if (_booking || _id.isEmpty || !_bookable) return;
    setState(() => _booking = true);
    SocketService.instance.bookTrip(
      tripId: _id,
      passengerName: widget.passengerName,
      passengerPhone: widget.passengerPhone,
    );
    // The passenger list updates itself via the `trip_updated` broadcast.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Подробно'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRouteCard(),
            const SizedBox(height: 12),
            _buildInfoCard(),
            const SizedBox(height: 12),
            _buildDriverCard(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _bookable ? _bookTrip : null,
              icon: _booking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.event_seat_rounded),
              label: Text(
                _bookable ? 'Брон кардан' : 'Ҷой дастрас нест',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.gray300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Big flat card with the full from -> to route and the price.
  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0052CC), Color(0xFF1683FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _isActive
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.gray300.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isActive ? 'ДАСТРАС' : 'БАСТА',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: _isActive ? Colors.greenAccent : AppColors.gray600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$_price сомонӣ',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _routeRow(
            icon: Icons.trip_origin_rounded,
            iconColor: Colors.greenAccent,
            text: _from,
          ),
          Container(
            margin: const EdgeInsets.only(left: 10),
            width: 2,
            height: 22,
            color: Colors.white54,
          ),
          _routeRow(
            icon: Icons.location_on_rounded,
            iconColor: Colors.redAccent,
            text: _to,
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Flat info card: seats, departure time, announcement id.
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _flatDecoration(),
      child: Column(
        children: [
          _infoTile(
            icon: Icons.event_seat_rounded,
            label: 'Ҷойҳои холӣ',
            value: _seats,
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          _infoTile(
            icon: Icons.schedule_rounded,
            label: 'Вақти сафар',
            value: _departure.isEmpty ? '—' : _departure,
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          _infoTile(
            icon: Icons.timelapse_rounded,
            label: 'Давомнокии сафар',
            value: _durationLabel,
          ),
        ],
      ),
    );
  }

  /// Driver details card with name and phone number.
  Widget _buildDriverCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _flatDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.lightBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 28,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverName.isEmpty ? 'Ронанда' : _driverName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 15,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _driverPhone.isEmpty ? '—' : _driverPhone,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_carBrand.isNotEmpty ||
              _carModel.isNotEmpty ||
              _carColor.isNotEmpty ||
              _carPlate.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.cardBorder),
            const SizedBox(height: 12),
            _infoTile(
              icon: Icons.directions_car_rounded,
              label: 'Мошин',
              value: [
                _carBrand,
                _carModel,
              ].where((value) => value.isNotEmpty).join(' '),
            ),
            _infoTile(
              icon: Icons.palette_rounded,
              label: 'Ранг',
              value: _carColor.isEmpty ? '—' : _carColor,
            ),
            _infoTile(
              icon: Icons.pin_rounded,
              label: 'Рақами мошин',
              value: _carPlate.isEmpty ? '—' : _carPlate,
            ),
          ],
        ],
      ),
    );
  }

  String get _durationLabel {
    if (_durationMinutes <= 0) return '—';
    final hours = _durationMinutes ~/ 60;
    final minutes = _durationMinutes % 60;
    if (hours == 0) return '$minutes дақиқа';
    if (minutes == 0) return '$hours соат';
    return '$hours соат $minutes дақиқа';
  }

  /// Flat, modern card decoration: white surface, hairline border, no shadow.
  BoxDecoration _flatDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
