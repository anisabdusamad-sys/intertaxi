import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

/// Singleton service managing the Socket.IO connection to the Flask-SocketIO backend.
///
/// Handles connection lifecycle and provides typed event streams for:
/// - Driver trip posting (`post_trip` / `new_trip`)
/// - Passenger trip search (`get_trips` / `trips_list`)
/// - Passenger trip booking (`book_trip` / `booking_confirmed` / `trip_updated`)
class SocketService {
  SocketService._();

  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  bool _isConnected = false;

  // Controllers for broadcasting events to listeners
  final _newOrderController = StreamController<Map<String, dynamic>>.broadcast();
  final _orderAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _locationUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  // Trip-specific controllers
  final _newTripController = StreamController<Map<String, dynamic>>.broadcast();
  final _tripsListController = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _bookingConfirmedController = StreamController<Map<String, dynamic>>.broadcast();
  final _tripUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of new orders broadcast from the server (for drivers).
  Stream<Map<String, dynamic>> get onNewOrder => _newOrderController.stream;

  /// Stream of order accepted events (for passengers).
  Stream<Map<String, dynamic>> get onOrderAccepted => _orderAcceptedController.stream;

  /// Stream of driver GPS location updates (for passengers tracking a driver).
  Stream<Map<String, dynamic>> get onLocationUpdate => _locationUpdateController.stream;

  /// Stream of connection status changes (true = connected, false = disconnected).
  Stream<bool> get onConnectionStatus => _connectionStatusController.stream;

  /// Stream of newly posted trips (broadcast when any driver posts a trip).
  Stream<Map<String, dynamic>> get onNewTrip => _newTripController.stream;

  /// Stream of trips list received from the server (response to get_trips or on connect).
  Stream<List<Map<String, dynamic>>> get onTripsList => _tripsListController.stream;

  /// Stream of booking confirmation events (for the passenger who booked).
  Stream<Map<String, dynamic>> get onBookingConfirmed => _bookingConfirmedController.stream;

  /// Stream of trip update events (broadcast when a trip is booked / status changes).
  Stream<Map<String, dynamic>> get onTripUpdated => _tripUpdatedController.stream;

  /// Stream of error messages from the server.
  Stream<String> get onError => _errorController.stream;

  /// Whether the socket is currently connected.
  bool get isConnected => _isConnected;

  /// The underlying socket ID (null when disconnected).
  String? get socketId => _socket?.id;

  /// Connects to the Flask-SocketIO server.
  ///
  /// [url] is optional — when omitted, the effective backend address from
  /// [ApiService.resolveBaseUrl] is used (custom override if the user set
  /// one in Profile → Сервер, otherwise the platform default).
  /// [userId] and [role] are sent as query parameters so the server can
  /// identify and route messages to this client.
  Future<void> connect({
    String? url,
    required String userId,
    required String role,
  }) async {
    // Avoid creating a duplicate connection.
    if (_socket != null && _isConnected) {
      debugPrint('[SocketService] Already connected.');
      return;
    }

    url ??= await ApiService.resolveBaseUrl();

    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableForceNew()
          .setQuery({'user_id': userId, 'role': role})
          .build(),
    );

    _socket!.connect();
    _registerEventHandlers();
  }

  void _registerEventHandlers() {
    final socket = _socket!;

    socket.onConnect((_) {
      _isConnected = true;
      _connectionStatusController.add(true);
      debugPrint('[SocketService] Connected — id: ${socket.id}');
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      _connectionStatusController.add(false);
      debugPrint('[SocketService] Disconnected');
    });

    socket.onConnectError((error) {
      _isConnected = false;
      _connectionStatusController.add(false);
      debugPrint('[SocketService] Connection error: $error');
    });

    socket.onError((error) {
      debugPrint('[SocketService] Socket error: $error');
    });

    // --- Application events ---

    // New order broadcast (driver receives this)
    socket.on('new_order', (data) {
      debugPrint('[SocketService] new_order received: $data');
      if (data is Map<String, dynamic>) {
        _newOrderController.add(data);
      } else if (data is String) {
        try {
          _newOrderController.add(jsonDecode(data) as Map<String, dynamic>);
        } catch (_) {
          debugPrint('[SocketService] Failed to parse new_order data');
        }
      }
    });

    // Order accepted broadcast (passenger receives this)
    socket.on('accept_order', (data) {
      debugPrint('[SocketService] accept_order received: $data');
      if (data is Map<String, dynamic>) {
        _orderAcceptedController.add(data);
      } else if (data is String) {
        try {
          _orderAcceptedController.add(jsonDecode(data) as Map<String, dynamic>);
        } catch (_) {
          debugPrint('[SocketService] Failed to parse accept_order data');
        }
      }
    });

    // Driver location update (passenger receives this)
    socket.on('update_location', (data) {
      debugPrint('[SocketService] update_location received: $data');
      if (data is Map<String, dynamic>) {
        _locationUpdateController.add(data);
      } else if (data is String) {
        try {
          _locationUpdateController.add(jsonDecode(data) as Map<String, dynamic>);
        } catch (_) {
          debugPrint('[SocketService] Failed to parse update_location data');
        }
      }
    });

    // Generic server message (optional logging)
    socket.on('message', (data) {
      debugPrint('[SocketService] message: $data');
    });

    // --- Trip events (new architecture) ---

    // New trip posted by any driver (broadcast)
    socket.on('new_trip', (data) {
      debugPrint('[SocketService] new_trip received: $data');
      if (data is Map<String, dynamic>) {
        _newTripController.add(data);
      } else if (data is String) {
        try {
          _newTripController.add(jsonDecode(data) as Map<String, dynamic>);
        } catch (_) {
          debugPrint('[SocketService] Failed to parse new_trip data');
        }
      }
    });

    // List of trips (response to get_trips or initial connect)
    socket.on('trips_list', (data) {
      debugPrint('[SocketService] trips_list received');
      if (data is Map<String, dynamic>) {
        final trips = data['trips'];
        if (trips is List) {
          _tripsListController.add(
            trips.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          );
        }
      } else if (data is String) {
        try {
          final decoded = jsonDecode(data) as Map<String, dynamic>;
          final trips = decoded['trips'];
          if (trips is List) {
            _tripsListController.add(
              trips.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            );
          }
        } catch (_) {
          debugPrint('[SocketService] Failed to parse trips_list data');
        }
      }
    });

    // Booking confirmation (for the passenger who booked)
    socket.on('booking_confirmed', (data) {
      debugPrint('[SocketService] booking_confirmed received: $data');
      if (data is Map<String, dynamic>) {
        _bookingConfirmedController.add(data);
      } else if (data is String) {
        try {
          _bookingConfirmedController.add(jsonDecode(data) as Map<String, dynamic>);
        } catch (_) {
          debugPrint('[SocketService] Failed to parse booking_confirmed data');
        }
      }
    });

    // Trip updated (broadcast when a trip is booked / status changes)
    socket.on('trip_updated', (data) {
      debugPrint('[SocketService] trip_updated received: $data');
      if (data is Map<String, dynamic>) {
        _tripUpdatedController.add(data);
      } else if (data is String) {
        try {
          _tripUpdatedController.add(jsonDecode(data) as Map<String, dynamic>);
        } catch (_) {
          debugPrint('[SocketService] Failed to parse trip_updated data');
        }
      }
    });

    // Server error messages
    socket.on('error', (data) {
      debugPrint('[SocketService] error received: $data');
      if (data is Map<String, dynamic>) {
        final msg = data['message']?.toString() ?? 'Unknown error';
        _errorController.add(msg);
      } else if (data is String) {
        try {
          final decoded = jsonDecode(data) as Map<String, dynamic>;
          final msg = decoded['message']?.toString() ?? 'Unknown error';
          _errorController.add(msg);
        } catch (_) {
          _errorController.add(data);
        }
      }
    });
  }

  /// Emits a `new_order` event to the server.
  void sendNewOrder(Map<String, dynamic> orderData) {
    if (!_isConnected || _socket == null) {
      debugPrint('[SocketService] Cannot send new_order — not connected');
      return;
    }
    _socket!.emit('new_order', orderData);
    debugPrint('[SocketService] Emitted new_order: $orderData');
  }

  /// Emits an `accept_order` event to the server.
  void acceptOrder({
    required String orderId,
    required Map<String, dynamic> driverData,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('[SocketService] Cannot accept_order — not connected');
      return;
    }
    final payload = {
      'order_id': orderId,
      ...driverData,
    };
    _socket!.emit('accept_order', payload);
    debugPrint('[SocketService] Emitted accept_order: $payload');
  }

  /// Emits an `update_location` event to the server.
  void updateLocation({
    required double lat,
    required double lng,
    String? orderId,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('[SocketService] Cannot update_location — not connected');
      return;
    }
    final payload = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      if (orderId != null) 'order_id': orderId,
    };
    _socket!.emit('update_location', payload);
    debugPrint('[SocketService] Emitted update_location: $payload');
  }

  /// Emits a `post_trip` event so a driver can announce a new trip.
  void postTrip(Map<String, dynamic> tripData) {
    if (!_isConnected || _socket == null) {
      debugPrint('[SocketService] Cannot post_trip — not connected');
      return;
    }
    _socket!.emit('post_trip', tripData);
    debugPrint('[SocketService] Emitted post_trip: $tripData');
  }

  /// Emits a `get_trips` event to request active trips (optionally filtered).
  void getTrips({String? from, String? to}) {
    if (!_isConnected || _socket == null) {
      debugPrint('[SocketService] Cannot get_trips — not connected');
      return;
    }
    final payload = <String, dynamic>{};
    if (from != null && from.trim().isNotEmpty) payload['from'] = from.trim();
    if (to != null && to.trim().isNotEmpty) payload['to'] = to.trim();
    _socket!.emit('get_trips', payload);
    debugPrint('[SocketService] Emitted get_trips: $payload');
  }

  /// Emits a `book_trip` event so a passenger can book a seat.
  void bookTrip({
    required String tripId,
    String? passengerName,
    String? passengerPhone,
  }) {
    if (!_isConnected || _socket == null) {
      debugPrint('[SocketService] Cannot book_trip — not connected');
      return;
    }
    final payload = <String, dynamic>{
      'trip_id': tripId,
      if (passengerName != null) 'passenger_name': passengerName,
      if (passengerPhone != null) 'passenger_phone': passengerPhone,
    };
    _socket!.emit('book_trip', payload);
    debugPrint('[SocketService] Emitted book_trip: $payload');
  }

  /// Disconnects from the server and cleans up resources.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _connectionStatusController.add(false);
    debugPrint('[SocketService] Disposed');
  }

  /// Closes all stream controllers. Call when the app is shutting down.
  void dispose() {
    disconnect();
    _newOrderController.close();
    _orderAcceptedController.close();
    _locationUpdateController.close();
    _connectionStatusController.close();
    _newTripController.close();
    _tripsListController.close();
    _bookingConfirmedController.close();
    _tripUpdatedController.close();
    _errorController.close();
  }
}
