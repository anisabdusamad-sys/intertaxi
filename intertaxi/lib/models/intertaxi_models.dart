import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';

/// Order model — represents a driver's ride announcement (эълон)
class Order {
  final String id;
  final String fromLocation;
  final String toLocation;
  final String price;
  final String duration;
  final int durationMinutes;
  final int seats;
  final String notes;
  final String createdAt;
  final String departureTime;
  final String driverName;
  final String driverPhone;
  final String carBrand;
  final String carModel;
  final String carColor;
  final String carPlate;

  Order({
    required this.id,
    required this.fromLocation,
    required this.toLocation,
    required this.price,
    required this.duration,
    this.durationMinutes = 0,
    required this.seats,
    required this.notes,
    required this.createdAt,
    this.departureTime = '',
    this.driverName = '',
    this.driverPhone = '',
    this.carBrand = '',
    this.carModel = '',
    this.carColor = '',
    this.carPlate = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromLocation': fromLocation,
    'toLocation': toLocation,
    'price': price,
    'duration': duration,
    'durationMinutes': durationMinutes,
    'seats': seats,
    'notes': notes,
    'createdAt': createdAt,
    'departureTime': departureTime,
    'driverName': driverName,
    'driverPhone': driverPhone,
    'carBrand': carBrand,
    'carModel': carModel,
    'carColor': carColor,
    'carPlate': carPlate,
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String? ?? '',
    fromLocation: json['fromLocation'] as String? ?? '',
    toLocation: json['toLocation'] as String? ?? '',
    price: json['price'] as String? ?? '',
    duration: json['duration'] as String? ?? '',
    durationMinutes: json['durationMinutes'] as int? ?? 0,
    seats: json['seats'] as int? ?? 0,
    notes: json['notes'] as String? ?? '',
    createdAt: json['createdAt'] as String? ?? '',
    departureTime: json['departureTime'] as String? ?? '',
    driverName: json['driverName'] as String? ?? '',
    driverPhone: json['driverPhone'] as String? ?? '',
    carBrand: json['carBrand'] as String? ?? '',
    carModel: json['carModel'] as String? ?? '',
    carColor: json['carColor'] as String? ?? '',
    carPlate: json['carPlate'] as String? ?? '',
  );
}

/// Persists an order to SharedPreferences so it survives app restarts / refresh
Future<void> saveOrder(Order order) async {
  final prefs = await SharedPreferences.getInstance();
  final orders = await loadOrders();
  orders.add(order);
  await prefs.setString(
    'saved_orders',
    jsonEncode(orders.map((o) => o.toJson()).toList()),
  );
}

/// Loads all saved orders from SharedPreferences
Future<List<Order>> loadOrders() async {
  final prefs = await SharedPreferences.getInstance();
  final ordersJson = prefs.getString('saved_orders');
  if (ordersJson == null || ordersJson.isEmpty) return [];
  final List<dynamic> decoded = jsonDecode(ordersJson);
  return decoded
      .map((item) => Order.fromJson(item as Map<String, dynamic>))
      .toList();
}

/// Deletes a single order by id — from the SERVER (so the announcement also
/// disappears for passengers via the `trip_deleted` broadcast) and from local
/// storage.
Future<void> deleteOrder(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final orders = await loadOrders();
  Order? order;
  for (final o in orders) {
    if (o.id == id) {
      order = o;
      break;
    }
  }

  // 1) Delete on the server. New announcements store the server UUID as
  //    their local id; older ones fall back to a content match so the right
  //    server row is still removed.
  final serverId = _looksLikeUuid(id) ? id : await _resolveServerTripId(order);
  if (serverId != null && serverId.isNotEmpty) {
    await ApiService.deleteTrip(serverId);
  }

  // 2) Always remove the local copy.
  orders.removeWhere((o) => o.id == id);
  await prefs.setString(
    'saved_orders',
    jsonEncode(orders.map((o) => o.toJson()).toList()),
  );
}

bool _looksLikeUuid(String id) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(id);

/// Finds the server trip matching the given local order by its content
/// (route + driver + price) so old announcements that only carry a local
/// timestamp id can still be removed from the server.
Future<String?> _resolveServerTripId(Order? order) async {
  if (order == null) return null;
  final trips = await ApiService.fetchTrips();
  final norm = (String? s) => (s ?? '').trim().toLowerCase();
  final priceNum = int.tryParse(order.price.replaceAll(RegExp(r'[^0-9]'), ''));
  final candidates = <Map<String, dynamic>>[];
  for (final t in trips) {
    if (norm(t['from_location']) != norm(order.fromLocation)) continue;
    if (norm(t['to_location']) != norm(order.toLocation)) continue;
    if (order.driverPhone.isNotEmpty &&
        norm(t['driver_phone']) != norm(order.driverPhone) &&
        norm(t['driver_id']) != norm(order.driverPhone)) {
      continue;
    }
    if (priceNum != null &&
        t['price'] is num &&
        (t['price'] as num) != priceNum) {
      continue;
    }
    candidates.add(t);
  }
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.first['id']?.toString();
  final depart = order.departureTime.trim();
  if (depart.isNotEmpty) {
    for (final t in candidates) {
      if (norm(t['departure_time']) == norm(depart)) {
        return t['id']?.toString();
      }
    }
  }
  return candidates.first['id']?.toString();
}
