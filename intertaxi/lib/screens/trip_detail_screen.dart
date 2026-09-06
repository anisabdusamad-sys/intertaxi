import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';

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

class BookingSentScreen extends StatelessWidget {
  final int requestedSeats;
  final String from;
  final String to;

  const BookingSentScreen({
    super.key,
    required this.requestedSeats,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Брон фиристода шуд'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 42,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Дархости шумо фиристода шуд',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  '$requestedSeats ҷой • $from → $to',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Лутфан мунтазир монед. Ронанда ба дархости шумо ҷавоб медиҳад.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    child: const Text('Ба саҳифаи асосӣ'),
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

class _TripDetailScreenState extends State<TripDetailScreen> {
  bool _booking = false;
  int _requestedSeats = 1;

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
    return '$hour:$minute $day.$month.${parsed.year}';
  }

  int get _durationMinutes =>
      int.tryParse(widget.trip['duration_minutes']?.toString() ?? '') ?? 0;
  String get _carBrand =>
      widget.trip['car_brand']?.toString().trim() ??
      widget.trip['carBrand']?.toString().trim() ??
      '';
  String get _carColor => widget.trip['car_color']?.toString() ?? '';
  String get _carPlate => widget.trip['car_plate']?.toString() ?? '';
  String get _driverName => widget.trip['driver_name']?.toString() ?? '';
  String get _driverPhone => widget.trip['driver_phone']?.toString() ?? '';
  bool get _isActive => widget.trip['status']?.toString() == 'active';
  int get _seatsInt => int.tryParse(_seats) ?? 0;
  bool get _bookable => _isActive && _seatsInt > 0;

  String get _vehicleName => _carBrand.isNotEmpty ? _carBrand : '—';

  String? get _vehicleLogoAsset {
    const brandLogos = {
      'Mercedes': 'assets/logos/1.jpg',
      'Toyota': 'assets/logos/2.jpg',
      'Honda': 'assets/logos/3.jpg',
      'Hyundai': 'assets/logos/4.jpg',
      'Opel': 'assets/logos/5.jpg',
      'BYD': 'assets/logos/6.jpg',
      'KIA': 'assets/logos/7.jpg',
      'Lexus': 'assets/logos/8.jpg',
      'Nissan': 'assets/logos/9.jpg',
      'Audi': 'assets/logos/10.jpg',
      'Ford': 'assets/logos/11.jpg',
      'BMW': 'assets/logos/12.jpg',
    };
    return brandLogos[_carBrand.trim()];
  }

  String get _formattedPlate {
    final compact = _carPlate.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final match = RegExp(
      r'^(\d{4})([A-ZА-ЯЁ]{1,3})(\d{2})$',
    ).firstMatch(compact);
    if (match != null) {
      return '${match.group(1)} ${match.group(2)} ${match.group(3)}';
    }
    return _carPlate.trim().isEmpty
        ? '—'
        : _carPlate.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
  }

  Color get _carColorSwatch {
    const colors = {
      'сафед': Color(0xFFE8EDF5),
      'сиёҳ': Color(0xFF252A34),
      'нуқрагӣ': Color(0xFFB8C0CC),
      'кабуд': Color(0xFF1769E0),
      'kabud': Color(0xFF1769E0),
      'blue': Color(0xFF1769E0),
      'сурх': Color(0xFFE53935),
      'нилуфарӣ': Color(0xFF8E44AD),
      'нилӯфарӣ': Color(0xFF8E44AD),
      'ҳафтранг': Color(0xFFF5A623),
      'сабз': Color(0xFF35A66F),
      'зард': Color(0xFFFFC107),
      'зар': Color(0xFFFFC107),
      'zar': Color(0xFFFFC107),
      'yellow': Color(0xFFFFC107),
    };
    return colors[_carColor.trim().toLowerCase()] ?? AppColors.primaryBlue;
  }

  // --- Actions --------------------------------------------------------------

  Future<void> _bookTrip() async {
    if (_booking || _id.isEmpty || !_bookable) return;
    setState(() => _booking = true);
    final result = await ApiService.createBooking(
      tripId: _id,
      passengerName: widget.passengerName,
      passengerPhone: widget.passengerPhone,
      requestedSeats: _requestedSeats,
    );
    if (!mounted) return;
    setState(() => _booking = false);
    if (result['ok'] == true) {
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSentScreen(
            requestedSeats: _requestedSeats,
            from: _from,
            to: _to,
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['error']?.toString() ?? 'Брон кардан иҷро нашуд'),
        backgroundColor: Colors.redAccent,
      ),
    );
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
            _buildSeatSelector(),
            if (_hasVehicleDetails) ...[
              const SizedBox(height: 12),
              _buildVehicleCard(),
            ],
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

  Widget _buildSeatSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_seat_rounded, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Чанд ҷой брон мекунед?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          DropdownButton<int>(
            value: _requestedSeats,
            items: List.generate(
              _seatsInt,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('${index + 1} ҷой'),
              ),
            ),
            onChanged: _booking
                ? null
                : (value) => setState(() => _requestedSeats = value ?? 1),
          ),
        ],
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
          const SizedBox(height: 14),
          _buildDriverProfile(),
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

  Widget _buildDriverProfile() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white54),
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 24,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _driverName.isEmpty ? 'Ронанда' : _driverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _driverPhone.isEmpty ? 'Рақам нест' : _driverPhone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.verified_rounded, color: Colors.white70, size: 20),
      ],
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

  /// Flat info card with the key trip details arranged for quick scanning.
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _flatDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _summaryTile(
                  icon: Icons.event_seat_rounded,
                  label: 'Ҷойҳои холӣ',
                  value: _seats,
                  suffix: 'ҷой',
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                  icon: Icons.timelapse_rounded,
                  label: 'Давомнокӣ',
                  value: _buildDurationLabel(),
                  color: const Color(0xFFE18332),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _summaryTile(
            icon: Icons.schedule_rounded,
            label: 'Вақти сафар',
            value: _departure.isEmpty ? '—' : _departure,
            color: const Color(0xFF7A55D8),
            fullValue: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? suffix,
    bool fullValue = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: fullValue ? 2 : 1,
                  overflow: fullValue
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fullValue ? 14 : 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 3),
                Text(
                  suffix,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _buildDurationLabel() {
    if (_durationMinutes <= 0) return '—';
    final hours = _durationMinutes ~/ 60;
    final minutes = _durationMinutes % 60;
    if (hours == 0) return '$minutes дақ.';
    if (minutes == 0) return '$hours соат';
    return '$hours с. $minutes дақ.';
  }

  bool get _hasVehicleDetails =>
      _carBrand.isNotEmpty || _carColor.isNotEmpty || _carPlate.isNotEmpty;

  /// Vehicle details displayed as compact premium badges.
  Widget _buildVehicleCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: _flatDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Маълумоти мошин',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 11,
                child: _vehicleItem(
                  Icons.directions_car_rounded,
                  'Мошин',
                  _vehicleName,
                  logoAsset: _vehicleLogoAsset,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 13, child: _buildColorBadge()),
            ],
          ),
          const SizedBox(height: 8),
          _vehicleItem(
            Icons.pin_rounded,
            'Рақами мошин',
            _formattedPlate,
            plate: true,
          ),
        ],
      ),
    );
  }

  Widget _buildColorBadge() {
    final hasColor = _carColor.isNotEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: _carColorSwatch.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _carColorSwatch.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: hasColor ? _carColorSwatch : AppColors.gray300,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _carColorSwatch.withValues(alpha: 0.30),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Ранг',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  hasColor ? _carColor : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleItem(
    IconData icon,
    String label,
    String value, {
    Color? swatch,
    bool plate = false,
    String? logoAsset,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (logoAsset != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    logoAsset,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Icon(icon, size: 18, color: AppColors.primaryBlue),
                  ),
                )
              else
                Icon(icon, size: 18, color: AppColors.primaryBlue),
              if (swatch != null) ...[
                const Spacer(),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: swatch.withValues(alpha: 0.35),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: plate ? 16 : 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: plate ? 1.5 : 0,
            ),
          ),
        ],
      ),
    );
  }

  /// Flat, modern card decoration: white surface, hairline border, no shadow.
  BoxDecoration _flatDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.cardBorder),
    );
  }
}
