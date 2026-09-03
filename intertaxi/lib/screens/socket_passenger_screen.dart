import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/socket_service.dart';

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
      if (!_trips.any((x) => x['id'] == t['id'])) {
        setState(() => _trips.insert(0, t));
      }
    });

    _updSub = SocketService.instance.onTripUpdated.listen((t) {
      if (!mounted) return;
      final i = _trips.indexWhere((x) => x['id'] == t['id']);
      if (i >= 0) setState(() => _trips[i] = t);
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

  void _book(Map<String, dynamic> trip) {
    final id = trip['id']?.toString() ?? '';
    if (id.isEmpty || !_isConnected) return;
    SocketService.instance.bookTrip(
      tripId: id,
      passengerName: widget.passengerName,
      passengerPhone: widget.passengerPhone,
    );
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _listSub?.cancel();
    _newSub?.cancel();
    _updSub?.cancel();
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
          Expanded(child: _trips.isEmpty ? _buildEmpty() : _buildList()),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (_, i) => _tripCard(_trips[i]),
    );
  }

  Widget _tripCard(Map<String, dynamic> t) {
    final from = t['from_location'] ?? 'Unknown';
    final to = t['to_location'] ?? 'Unknown';
    final price = t['price'] ?? '0';
    final seats = t['available_seats'] ?? '0';
    final dep = t['departure_time'] ?? '';
    final dName = t['driver_name'] ?? '';
    final dPhone = t['driver_phone'] ?? '';
    final active = t['status'] == 'active';
    final seatsInt = int.tryParse(seats.toString()) ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    active ? 'AVAILABLE' : 'BOOKED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '$price Somoni',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0066FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.my_location, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Text(from),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                Text(to),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_seat, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$seats seats',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (dep.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    dep.length > 16 ? dep.substring(0, 16) : dep,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            if (dName.isNotEmpty || dPhone.isNotEmpty) ...[
              const Divider(),
              if (dName.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: Color(0xFF0066FF),
                    ),
                    const SizedBox(width: 8),
                    Text(dName),
                  ],
                ),
              if (dPhone.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Color(0xFF0066FF)),
                    const SizedBox(width: 8),
                    Text(dPhone),
                  ],
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: active && seatsInt > 0 ? () => _book(t) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  active && seatsInt > 0 ? 'Book Trip' : 'Not Available',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
