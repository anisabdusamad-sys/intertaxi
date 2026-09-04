import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class SocketDriverScreen extends StatefulWidget {
  final String driverName;
  final String driverPhone;
  final String driverCar;

  const SocketDriverScreen({
    super.key,
    required this.driverName,
    required this.driverPhone,
    this.driverCar = '',
  });

  @override
  State<SocketDriverScreen> createState() => _SocketDriverScreenState();
}

class _SocketDriverScreenState extends State<SocketDriverScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  bool _isConnected = false;
  String _status = 'Disconnected';
  Color _statusColor = Colors.red;
  final List<Map<String, dynamic>> _myTrips = [];

  StreamSubscription<bool>? _connSub;
  StreamSubscription<Map<String, dynamic>>? _newTripSub;
  StreamSubscription<Map<String, dynamic>>? _tripUpdSub;
  StreamSubscription<Map<String, dynamic>>? _tripDelSub;
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
    });

    _newTripSub = SocketService.instance.onNewTrip.listen((trip) {
      if (!mounted) return;
      if (trip['driver_id'] == widget.driverPhone) {
        setState(() => _myTrips.insert(0, trip));
      }
    });

    _tripUpdSub = SocketService.instance.onTripUpdated.listen((t) {
      if (!mounted) return;
      final i = _myTrips.indexWhere((x) => x['id'] == t['id']);
      if (i >= 0) setState(() => _myTrips[i] = t);
    });

    // A trip was deleted (by this driver or elsewhere) — keep our list in sync.
    _tripDelSub = SocketService.instance.onTripDeleted.listen((data) {
      if (!mounted) return;
      final id = data['id']?.toString();
      if (id == null || id.isEmpty) return;
      setState(() {
        _myTrips.removeWhere((x) => x['id']?.toString() == id);
      });
    });

    _errSub = SocketService.instance.onError.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    });
  }

  void _connect() {
    SocketService.instance.connect(userId: widget.driverPhone, role: 'driver');
  }

  Future<void> _publish() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected'), backgroundColor: Colors.red),
      );
      return;
    }
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    final price = _priceCtrl.text.trim();
    final seats = _seatsCtrl.text.trim();
    if (from.isEmpty || to.isEmpty || price.isEmpty || seats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill all fields'), backgroundColor: Colors.orange),
      );
      return;
    }
    final payload = {
      'driver_id': widget.driverPhone,
      'driver_name': widget.driverName,
      'driver_phone': widget.driverPhone,
      'from_location': from,
      'to_location': to,
      'price': int.tryParse(price) ?? 0,
      'available_seats': int.tryParse(seats) ?? 0,
      'departure_time': _dateCtrl.text.isEmpty
          ? DateTime.now().toIso8601String()
          : '${_dateCtrl.text}T${_timeCtrl.text}:00',
    };

    // Primary path: real-time Socket.IO emit. The server broadcasts the trip
    // back on `new_trip`, which the listener below inserts into _myTrips.
    final sent = SocketService.instance.postTrip(payload);

    // Fallback path: if the socket dropped between the status check and the
    // emit, push the announcement via REST so it is never lost.
    if (!sent) {
      final ok = await ApiService.postTrip(payload);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serverga ulanib bo\'lmadi (publish failed)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      // The trip is saved server-side, but no socket broadcast will reach us
      // while offline — show it in our own list immediately.
      setState(() {
        _myTrips.insert(0, {
          ...payload,
          'id': -(DateTime.now().millisecondsSinceEpoch),
          'status': 'active',
        });
      });
    }

    _fromCtrl.clear();
    _toCtrl.clear();
    _priceCtrl.clear();
    _seatsCtrl.clear();
    _dateCtrl.clear();
    _timeCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip published!'), backgroundColor: Colors.green),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null && mounted) {
      _dateCtrl.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null && mounted) {
      _timeCtrl.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _newTripSub?.cancel();
    _tripUpdSub?.cancel();
    _tripDelSub?.cancel();
    _errSub?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _priceCtrl.dispose();
    _seatsCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Driver - ${widget.driverName}'),
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
                Text(_status, style: TextStyle(fontSize: 12, color: _statusColor)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildForm(),
            const SizedBox(height: 24),
            Text('My Trips (${_myTrips.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildTripsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Post New Trip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _field(_fromCtrl, 'From (City)', Icons.my_location, Colors.green),
            const SizedBox(height: 12),
            _field(_toCtrl, 'To (City)', Icons.location_on, Colors.red),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_priceCtrl, 'Price (Somoni)', Icons.attach_money, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _field(_seatsCtrl, 'Seats', Icons.event_seat, Colors.blue)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(child: _field(_dateCtrl, 'Date', Icons.calendar_today, Colors.purple)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: AbsorbPointer(child: _field(_timeCtrl, 'Time', Icons.access_time, Colors.teal)),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isConnected ? _publish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Publish Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, Color color) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0066FF), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
      ),
    );
  }

  Widget _buildTripsList() {
    if (_myTrips.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(children: [
            Icon(Icons.directions_car, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No trips posted', style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _myTrips.length,
      itemBuilder: (_, i) => _tripCard(_myTrips[i]),
    );
  }

  /// Asks the server to delete one of the driver's own trips. Primary path:
  /// Socket.IO `delete_trip` (server broadcasts `trip_deleted` to everyone).
  /// Fallback: REST `DELETE /api/trips/<id>`.
  Future<void> _deleteTrip(Map<String, dynamic> t) async {
    final id = t['id']?.toString() ?? '';
    if (id.isEmpty || id.startsWith('-')) return; // offline placeholder row

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text(
          'Трип нест карда шавад? Мусофирон онро фавран мебинанд.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final sent = SocketService.instance.deleteTrip(id);
    if (!sent) {
      final ok = await ApiService.deleteTrip(id);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Нест карда нашуд (delete failed)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
  }

  Widget _tripCard(Map<String, dynamic> t) {
    final from = t['from_location'] ?? 'Unknown';
    final to = t['to_location'] ?? 'Unknown';
    final price = t['price'] ?? '0';
    final seats = t['available_seats'] ?? '0';
    final active = t['status'] == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(active ? 'ACTIVE' : 'BOOKED',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? Colors.green : Colors.grey)),
              ),
              const Spacer(),
              Text('$price Somoni', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0066FF))),
              const SizedBox(width: 4),
              // Delete this trip (broadcasts trip_deleted to all users)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                tooltip: 'Нест кардан',
                onPressed: () => _deleteTrip(t),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.my_location, size: 18, color: Colors.green), const SizedBox(width: 8), Text(from)]),
            Row(children: [const Icon(Icons.location_on, size: 18, color: Colors.red), const SizedBox(width: 8), Text(to)]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.event_seat, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text('$seats seats', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ],
        ),
      ),
    );
  }
}