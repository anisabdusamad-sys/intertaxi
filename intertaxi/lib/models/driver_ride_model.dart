import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'intertaxi_models.dart';

/// InterTaxi Driver Ride Model
/// Represents a driver's announced trip with an ordered route (list of stops).
/// The route allows segment matching: a driver "covers" a passenger's
/// origin -> destination if both stops exist on the route in the right order.
class DriverRide {
  final String id;
  final String driverName;
  final String driverPhone;
  final String carModel;
  final String carColor;
  final String carPlate;
  final int availableSeats;
  final DateTime departureTime;

  /// Ordered stops of the trip. [route.first] = origin, [route.last] = final
  /// destination. Intermediate stops make partial-segment matching possible.
  final List<String> route;

  /// Price per seat (in somoni) for the FULL route.
  final int fullRoutePrice;

  DriverRide({
    required this.id,
    required this.driverName,
    this.driverPhone = '',
    required this.carModel,
    required this.carColor,
    required this.carPlate,
    required this.availableSeats,
    required this.departureTime,
    required this.route,
    required this.fullRoutePrice,
  });

  /// True when the driver's route contains BOTH [from] and [to],
  /// and [from] comes before [to] on the route.
  bool coversSegment(String from, String to) {
    final originIdx = route.indexOf(from);
    final destIdx = route.indexOf(to);
    return originIdx != -1 && destIdx != -1 && originIdx < destIdx;
  }

  /// True when the driver goes exactly from [from] to [to] (no detours).
  bool isExactMatch(String from, String to) =>
      route.first == from && route.last == to;

  /// Price per seat for the requested segment, computed proportionally
  /// to the number of legs the passenger occupies on the driver's route.
  int priceForSegment(String from, String to) {
    final originIdx = route.indexOf(from);
    final destIdx = route.indexOf(to);
    if (originIdx == -1 || destIdx == -1 || destIdx <= originIdx) {
      return fullRoutePrice;
    }
    final totalLegs = route.length - 1;
    final segmentLegs = destIdx - originIdx;
    final proportional = fullRoutePrice * segmentLegs / totalLegs;
    return proportional.round().clamp(5, fullRoutePrice);
  }

  /// Stops the passenger will ride through (including origin & destination).
  List<String> segmentStops(String from, String to) {
    final originIdx = route.indexOf(from);
    final destIdx = route.indexOf(to);
    if (originIdx == -1 || destIdx == -1 || destIdx <= originIdx) {
      return route;
    }
    return route.sublist(originIdx, destIdx + 1);
  }

  /// Human-friendly departure time, e.g. "08:45".
  String get departureLabel {
    final h = departureTime.hour.toString().padLeft(2, '0');
    final m = departureTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Minutes until departure (clamped at 0 for "departing now").
  int get minutesUntilDeparture =>
      departureTime.difference(DateTime.now()).inMinutes.clamp(0, 24 * 60);

  /// Human-friendly countdown, e.g. "дар 25 дақиқа".
  String get countdownLabel {
    final minutes = minutesUntilDeparture;
    if (minutes < 1) return 'ҳозир меравад';
    if (minutes < 60) return 'дар $minutes дақиқа';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? 'дар $hours соат' : 'дар $hours соат $rest дақиқа';
  }
}

/// Repository that searches REAL driver-posted trips.
///
/// Trips are persisted by the driver flow via [saveOrder] (SharedPreferences
/// key `saved_orders`). This repository reads that real store and returns only
/// drivers who have actually announced a trip covering the requested route.
///
/// Swapping storage for another backend / a REST API only requires
/// replacing the body of [fetchMatchingRides] with the matching network call —
/// the returned type and the UI contract stay unchanged.
class DriverRideRepository {
  DriverRideRepository._();

  /// Reads the persisted driver announcements and returns matching rides.
  ///
  /// Fully asynchronous and non-blocking:
  ///  1. [SharedPreferences] is read through the async platform channel.
  ///  2. JSON decoding + filtering + sorting run on a background isolate
  ///     ([compute]) so the UI thread is never busy during a search.
  static Future<List<DriverRide>> fetchMatchingRides({
    required String from,
    required String to,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('saved_orders') ?? '';

    // No real driver data persisted yet → return an empty list immediately.
    // The UI then shows "Ҳоло дар ин масир ронандае нест".
    if (rawJson.isEmpty) return const <DriverRide>[];

    return compute(
      _searchSavedOrders,
      DriverRideSearchRequest(rawJson: rawJson, from: from, to: to),
    );
  }
}

/// Payload passed to the background isolate ([compute] takes a single arg).
class DriverRideSearchRequest {
  final String rawJson;
  final String from;
  final String to;

  const DriverRideSearchRequest({
    required this.rawJson,
    required this.from,
    required this.to,
  });
}

/// Runs on a background isolate: decodes persisted orders, keeps only trips
/// that cover the requested segment, and sorts by departure time.
List<DriverRide> _searchSavedOrders(DriverRideSearchRequest request) {
  final matches = <DriverRide>[];
  if (request.rawJson.isEmpty) return matches;

  final List<dynamic> decoded;
  try {
    decoded = jsonDecode(request.rawJson) as List<dynamic>;
  } catch (_) {
    // Corrupted storage — treat as "no trips" instead of crashing the UI.
    return matches;
  }

  for (final item in decoded) {
    if (item is! Map<String, dynamic>) continue;
    final order = Order.fromJson(item);
    final ride = orderToRide(order);
    if (ride == null) continue;
    if (ride.availableSeats > 0 &&
        ride.coversSegment(request.from, request.to)) {
      matches.add(ride);
    }
  }

  matches.sort((a, b) {
    final aExact = a.isExactMatch(request.from, request.to) ? 0 : 1;
    final bExact = b.isExactMatch(request.from, request.to) ? 0 : 1;
    if (aExact != bExact) return aExact - bExact;
    return a.departureTime.compareTo(b.departureTime);
  });

  return matches;
}

/// Maps a persisted driver announcement to a searchable [DriverRide].
/// Returns null when the announcement is not usable (missing route/price).
DriverRide? orderToRide(Order order) {
  final from = order.fromLocation.trim();
  final to = order.toLocation.trim();
  if (from.isEmpty || to.isEmpty) return null;

  final price =
      int.tryParse(order.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  if (price <= 0) return null;

  final departureRaw = order.departureTime.isNotEmpty
      ? order.departureTime
      : order.createdAt;
  final departure = DateTime.tryParse(departureRaw) ?? DateTime.now();

  final brand = order.carBrand.trim();
  final model = order.carModel.trim();
  final carModel = model.isNotEmpty ? '$brand $model'.trim() : brand;

  return DriverRide(
    id: order.id,
    driverName: order.driverName,
    driverPhone: order.driverPhone,
    carModel: carModel,
    carColor: order.carColor,
    carPlate: order.carPlate,
    availableSeats: order.seats,
    departureTime: departure,
    route: [from, to],
    fullRoutePrice: price,
  );
}

