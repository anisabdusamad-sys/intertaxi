import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Order model — represents a driver's ride announcement (эълон)
class Order {
  final String id;
  final String fromLocation;
  final String toLocation;
  final String price;
  final String duration;
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

/// Deletes a single order by id
Future<void> deleteOrder(String id) async {
  final prefs = await SharedPreferences.getInstance();
  final orders = await loadOrders();
  orders.removeWhere((o) => o.id == id);
  await prefs.setString(
    'saved_orders',
    jsonEncode(orders.map((o) => o.toJson()).toList()),
  );
}
