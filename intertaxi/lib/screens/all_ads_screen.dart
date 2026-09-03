import 'package:flutter/material.dart';

import '../models/intertaxi_models.dart' as models;
import '../services/api_service.dart';

/// InterTaxi — "Все объявления" tab.
///
/// Shows EVERY order / announcement left by drivers: the ones stored on this
/// device (SharedPreferences `saved_orders`) merged with the trips that have
/// reached the Flask backend (REST `GET /api/trips`). Unlike the home tab,
/// nothing here is filtered by a route — every driver ad is visible.
class AllAdsScreen extends StatefulWidget {
  const AllAdsScreen({super.key});

  @override
  State<AllAdsScreen> createState() => _AllAdsScreenState();
}

/// One announcement shown in the list (local device order OR backend trip).
class _AdItem {
  final String id;
  final String fromLocation;
  final String toLocation;
  final String price;
  final int seats;
  final DateTime? departureTime;
  final DateTime? createdAt;
  final String driverName;
  final String driverPhone;
  final String carBrand;
  final String carModel;
  final String carColor;
  final String carPlate;
  final String notes;
  final String source; // 'local' | 'backend'

  const _AdItem({
    required this.id,
    required this.fromLocation,
    required this.toLocation,
    required this.price,
    required this.seats,
    required this.departureTime,
    required this.createdAt,
    required this.driverName,
    required this.driverPhone,
    required this.carBrand,
    required this.carModel,
    required this.carColor,
    required this.carPlate,
    required this.notes,
    required this.source,
  });

  factory _AdItem.fromOrder(models.Order o) {
    return _AdItem(
      id: o.id,
      fromLocation: o.fromLocation,
      toLocation: o.toLocation,
      price: o.price,
      seats: o.seats,
      departureTime: DateTime.tryParse(o.departureTime),
      createdAt: DateTime.tryParse(o.createdAt),
      driverName: o.driverName,
      driverPhone: o.driverPhone,
      carBrand: o.carBrand,
      carModel: o.carModel,
      carColor: o.carColor,
      carPlate: o.carPlate,
      notes: o.notes,
      source: 'local',
    );
  }

  factory _AdItem.fromTrip(Map<String, dynamic> t) {
    final carBrand = '${t['car_brand'] ?? ''}'.trim();
    final carModel = '${t['car_model'] ?? ''}'.trim();
    return _AdItem(
      id: '${t['id'] ?? ''}',
      fromLocation: '${t['from_location'] ?? ''}',
      toLocation: '${t['to_location'] ?? ''}',
      price: '${t['price'] ?? ''}',
      seats: (t['available_seats'] as num?)?.toInt() ?? 0,
      departureTime: DateTime.tryParse('${t['departure_time'] ?? ''}'),
      createdAt: DateTime.tryParse('${t['created_at'] ?? ''}'),
      driverName: '${t['driver_name'] ?? ''}',
      driverPhone: '${t['driver_phone'] ?? ''}',
      carBrand: carBrand,
      carModel: carModel,
      carColor: '${t['car_color'] ?? ''}',
      carPlate: '${t['car_plate'] ?? ''}',
      notes: '',
      source: 'backend',
    );
  }
}
class _AllAdsScreenState extends State<AllAdsScreen> {
  bool _isLoading = true;
  String? _error;
  List<_AdItem> _ads = [];

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1) All orders saved on this device (driver announcements).
      final localOrders = await models.loadOrders();

      // 2) Trips that have reached the Flask backend (best-effort).
      final backendTrips = await ApiService.fetchTrips();

      if (!mounted) return;

      final items = <String, _AdItem>{};

      // Backend first, then local — a local item with the same id wins.
      for (final t in backendTrips) {
        final item = _AdItem.fromTrip(t);
        if (item.fromLocation.isEmpty || item.toLocation.isEmpty) continue;
        items[item.id.isEmpty ? 'backend:${items.length}' : item.id] = item;
      }
      for (final o in localOrders) {
        final item = _AdItem.fromOrder(o);
        if (item.fromLocation.isEmpty || item.toLocation.isEmpty) continue;
        items[item.id.isEmpty ? 'local:${items.length}' : item.id] = item;
      }

      final list = items.values.toList()
        ..sort((a, b) {
          // Newest post first; fall back to nearest departure.
          final aTime = a.createdAt ?? a.departureTime;
          final bTime = b.createdAt ?? b.departureTime;
          if (aTime != null && bTime != null) {
            return bTime.compareTo(aTime);
          }
          if (aTime != null) return -1;
          if (bTime != null) return 1;
          return 0;
        });

      setState(() => _ads = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Хатогӣ ҳангоми боркунии эълонҳо: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Все объявления',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadAds,
                tooltip: 'Навсозӣ',
                icon: const Icon(Icons.refresh_rounded,
                    color: Color(0xFF0066FF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _isLoading
                ? 'Боркунӣ...'
                : _ads.isEmpty
                    ? 'Ҳоло ягон эълони ронандагон нест'
                    : 'Ҳамаи эълонҳои ронандагон (${_ads.length})',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0066FF)));
    }

    if (_error != null) {
      return _MessageBlock(
        icon: Icons.error_outline_rounded,
        title: 'Хатогӣ',
        subtitle: _error!,
      );
    }

    if (_ads.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAds,
        color: const Color(0xFF0066FF),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            _MessageBlock(
              icon: Icons.campaign_rounded,
              title: 'Ҳоло эълонҳо нестанд',
              subtitle:
                  'Вақте ронандагон заказ мегузоранд, онҳо дар ин ҷо пайдо мешаванд.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAds,
      color: const Color(0xFF0066FF),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: _ads.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _AdCard(item: _ads[index]),
      ),
    );
  }
}
class _MessageBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MessageBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final _AdItem item;

  const _AdCard({required this.item});

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.${dt.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final carParts = <String>[
      item.carBrand,
      item.carModel,
    ].map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final carLabelParts = <String>[
      carParts.join(' '),
      item.carColor,
      item.carPlate,
    ].where((s) => s.isNotEmpty).toList();
    final carLabel = carLabelParts.join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF0066FF).withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route row
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded,
                  size: 18, color: Color(0xFF0066FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.fromLocation,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: Colors.grey),
              ),
              const Icon(Icons.location_on_rounded,
                  size: 18, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.toLocation,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              _SourceBadge(source: item.source),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFEEF1F5)),

          // Info rows
          _infoRow(Icons.payments_rounded, 'Нарх',
              '${item.price.isEmpty ? '—' : item.price} сомонӣ'),
          _infoRow(
              Icons.event_seat_rounded,
              'Ҷойҳо',
              item.seats <= 0 ? '—' : '${item.seats} ҷой'),
          if (_formatDateTime(item.departureTime).isNotEmpty)
            _infoRow(Icons.schedule_rounded, 'Рафтан',
                _formatDateTime(item.departureTime)),
          if (carLabel.isNotEmpty)
            _infoRow(Icons.directions_car_rounded, 'Мошин', carLabel),
          if (item.driverName.isNotEmpty)
            _infoRow(Icons.person_rounded, 'Ронанда', item.driverName),
          if (item.driverPhone.isNotEmpty)
            _infoRow(Icons.phone_rounded, 'Телефон', item.driverPhone),
          if (item.notes.isNotEmpty)
            _infoRow(Icons.sticky_note_2_rounded, 'Изоҳа', item.notes),
          if (_formatDateTime(item.createdAt).isNotEmpty)
            _infoRow(Icons.access_time_rounded, 'Эълон шуд',
                _formatDateTime(item.createdAt)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF0066FF)),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isLocal = source == 'local';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLocal
            ? const Color(0xFF0066FF).withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isLocal ? 'Локалӣ' : 'Сервер',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isLocal ? const Color(0xFF0066FF) : Colors.green[700],
        ),
      ),
    );
  }
}