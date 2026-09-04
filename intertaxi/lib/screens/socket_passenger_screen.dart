import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'trip_detail_screen.dart';

class SocketPassengerScreen extends StatefulWidget {
  final String passengerName;
  final String passengerPhone;

  const SocketPassengerScreen({
    super.key,
    required this.passengerName,
    required this.passengerPhone,
  });

  @override
  State<SocketPassengerScreen> createState() => _SocketPassengerScreenState();
}

class _SocketPassengerScreenState extends State<SocketPassengerScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  bool _isConnected = false;
  String _status = 'Disconnected';
  Color _statusColor = Colors.red;
  final List<Map<String, dynamic>> _trips = [];

  StreamSubscription<bool>? _connSub;
  StreamSubscription<List<Map<String, dynamic>>>? _listSub;
  StreamSubscription<Map<String, dynamic>>? _newSub;
  StreamSubscription<Map<String, dynamic>>? _updSub;
  StreamSubscription<Map<String, dynamic>>? _deletedSub;
  StreamSubscription<Map<String, dynamic>>? _bookSub;
  StreamSubscription<String>? _errSub;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _connect();
  }

  void _setupListeners() {
    _connSub = SocketService.instance.onConnectionStatus.listen((ok) {
      if (!mounted) return;
      setState(() {
        _isConnected = ok;
        _status = ok ? 'Connected' : 'Disconnected';
        _statusColor = ok ? Colors.green : Colors.red;
      });
      if (ok) SocketService.instance.getTrips();
    });

    _listSub = SocketService.instance.onTripsList.listen((trips) {
      if (!mounted) return;
      setState(() {
        _trips.clear();
        _trips.addAll(trips);
      });
    });

    _newSub = SocketService.instance.onNewTrip.listen((t) {
      if (!mounted) return;
      // Respect the active route filter: a newly posted trip is only shown
      // when it matches the EXACT route the passenger is searching for.
      final f = _fromCtrl.text.trim();
      final toFilter = _toCtrl.text.trim();
      final tFrom = t['from_location']?.toString() ?? '';
      final tTo = t['to_location']?.toString() ?? '';
      if (f.isNotEmpty && tFrom != f) return;
      if (toFilter.isNotEmpty && tTo != toFilter) return;
      if (!_trips.any((x) => x['id'] == t['id'])) {
        setState(() => _trips.insert(0, t));
      }
    });

    _updSub = SocketService.instance.onTripUpdated.listen((t) {
      if (!mounted) return;
      final i = _trips.indexWhere((x) => x['id'] == t['id']);
      if (i >= 0) setState(() => _trips[i] = t);
    });

    // A driver deleted their trip — remove it from the list in real time.
    _deletedSub = SocketService.instance.onTripDeleted.listen((data) {
      if (!mounted) return;
      final id = data['id']?.toString();
      if (id == null || id.isEmpty) return;
      setState(() {
        _trips.removeWhere((x) => x['id']?.toString() == id);
      });
    });

    _bookSub = SocketService.instance.onBookingConfirmed.listen((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking confirmed!'),
          backgroundColor: Colors.green,
        ),
      );
    });

    _errSub = SocketService.instance.onError.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    });
  }

  void _connect() {
    SocketService.instance.connect(
      userId: widget.passengerPhone,
      role: 'passenger',
    );
  }

  void _search() {
    if (_isConnected) {
      SocketService.instance.getTrips(
        from: _fromCtrl.text.trim(),
        to: _toCtrl.text.trim(),
      );
    } else {
      _loadViaRest();
    }
  }

  Future<void> _loadViaRest() async {
    try {
      final base = await ApiService.resolveBaseUrl();
      final uri = Uri.parse('$base/api/trips').replace(
        queryParameters: {
          if (_fromCtrl.text.trim().isNotEmpty) 'from': _fromCtrl.text.trim(),
          if (_toCtrl.text.trim().isNotEmpty) 'to': _toCtrl.text.trim(),
        },
      );
      final resp = await http.get(uri);
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['trips'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _trips.clear();
          _trips.addAll(list);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _listSub?.cancel();
    _newSub?.cancel();
    _updSub?.cancel();
    _deletedSub?.cancel();
    _bookSub?.cancel();
    _errSub?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Musofir - ${widget.passengerName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: _statusColor),
                const SizedBox(width: 4),
                Text(
                  _status,
                  style: TextStyle(fontSize: 12, color: _statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearch(),
          if (!_isConnected) _buildBanner(),
          Expanded(
            child: _visibleTrips.isEmpty ? _buildEmpty() : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.orange[50],
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Socket.IO disconnected',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(onPressed: _connect, child: const Text('Retry')),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadViaRest,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Load via REST'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _field(
                  _fromCtrl,
                  'From',
                  Icons.my_location,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_toCtrl, 'To', Icons.location_on, Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search),
              label: const Text('Search Trips'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0066FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon,
    Color color,
  ) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _isConnected ? 'No trips found' : 'Not connected',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _isConnected ? 'Waiting for drivers...' : 'Tap Load via REST',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          if (!_isConnected) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadViaRest,
              icon: const Icon(Icons.download),
              label: const Text('Load via REST'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    final visible = _visibleTrips;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visible.length,
      itemBuilder: (_, i) => _tripCard(visible[i]),
    );
  }

  /// Trips displayed on screen: ONLY the trips whose `from_location` AND
  /// `to_location` PRECISELY match the current search fields
  /// (trimmed, case-insensitive).
  ///
  /// The server already filters strictly (`GET /api/trips?from=...&to=...`
  /// uses `ilike`), but `new_trip` broadcasts and offline REST loads are
  /// double-checked here so a trip for a DIFFERENT route (e.g.
  /// "Кулоб -> Душанбе" while searching "Кулоб -> Восе") can never appear
  /// in the passenger's list.
  List<Map<String, dynamic>> get _visibleTrips {
    final f = _fromCtrl.text.trim().toLowerCase();
    final t = _toCtrl.text.trim().toLowerCase();
    if (f.isEmpty && t.isEmpty) return List.unmodifiable(_trips);
    return _trips.where((trip) {
      final tFrom =
          trip['from_location']?.toString().trim().toLowerCase() ?? '';
      final tTo = trip['to_location']?.toString().trim().toLowerCase() ?? '';
      if (f.isNotEmpty && tFrom != f) return false;
      if (t.isNotEmpty && tTo != t) return false;
      return true;
    }).toList();
  }

  /// Premium compact, flat, modern trip card.
  ///
  /// Shows ONLY: Driver Name (Ному Насаб), Phone Number (Рақами телефон),
  /// Available Seats (Ҷои нишаст), the Route (Масир: аз куҷо то куҷо) and a
  /// "Подробно" button that opens [TripDetailScreen] with the full info.
  Widget _tripCard(Map<String, dynamic> t) {
    final dName = t['driver_name']?.toString() ?? '';
    final dPhone = t['driver_phone']?.toString() ?? '';
    final seats = t['available_seats']?.toString() ?? '0';
    final from = t['from_location']?.toString() ?? '';
    final to = t['to_location']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetails(t),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Driver avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F0FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 24,
                        color: Color(0xFF0066FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Driver name + phone number
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dName.isEmpty ? 'Ронанда' : dName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_rounded,
                                size: 13,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                dPhone.isEmpty ? '—' : dPhone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 12),
                // Route (Масир: аз куҷо то куҷо).
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 14,
                      color: const Color(0xFFE2E8F0),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Масир: аз $from то $to',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Available seats (Ҷои нишаст) + "Подробно" button.
                Row(
                  children: [
                    const Icon(
                      Icons.event_seat_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Ҷои нишаст: $seats',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: () => _openDetails(t),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0066FF),
                          side: const BorderSide(
                            color: Color(0xFF0066FF),
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Подробно',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails(Map<String, dynamic> t) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          trip: t,
          passengerName: widget.passengerName,
          passengerPhone: widget.passengerPhone,
        ),
      ),
    );
  }
}
