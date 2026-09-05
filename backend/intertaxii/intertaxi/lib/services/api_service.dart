import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight HTTP client for the InterTaxi Flask backend.
///
/// All calls are best-effort: if the backend is offline or unreachable the
/// methods return empty/neutral values and never throw — the driver flow and
/// the passenger UI must keep working with locally stored data.
class ApiService {
  ApiService._();

  /// Effective server address for the InterTaxi Flask backend.
  ///
  /// The backend is now deployed on Render; this is the default address used
  /// by every REST and Socket.IO call. The user can still override it (see
  /// [setCustomBaseUrl]) for local development against a PC-running Flask.

  static const String _baseUrlPrefsKey = 'backend_url';
  static String? _customBaseUrl;
  /// Deployed backend (Render) — used for HTTP and Socket.IO alike.
  static const String defaultBaseUrl = 'https://intertaxi.onrender.com';

  static String _platformDefault() {
    return defaultBaseUrl;
  }

  /// Resolves the effective backend address: the user-configured override (if
  /// set) or the platform default. Async because the override is stored in prefs.
  static Future<String> resolveBaseUrl() async {
    if (_customBaseUrl != null) return _customBaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_baseUrlPrefsKey)?.trim() ?? '';
    if (saved.isNotEmpty) {
      _customBaseUrl = _normalizeUrl(saved);
      return _customBaseUrl!;
    }
    return _platformDefault();
  }

  /// Saves a custom server address (e.g. `https://intertaxi.onrender.com`).
  /// An empty value resets to the deployed default (Render).
  static Future<void> setCustomBaseUrl(String value) async {
    final trimmed = value.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      _customBaseUrl = null;
      await prefs.remove(_baseUrlPrefsKey);
      return;
    }
    final normalized = _normalizeUrl(trimmed);
    _customBaseUrl = normalized;
    await prefs.setString(_baseUrlPrefsKey, normalized);
  }

  /// Tidies up a user-typed address: adds scheme, strips trailing slash.
  static String _normalizeUrl(String value) {
    var cleaned = value.trim();
    if (!cleaned.contains('://')) {
      cleaned = 'https://$cleaned';
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  /// Pushes a driver trip/announcement to the backend (REST fallback used by
  /// the create-order flow). Returns `true` when the server accepted it.
  static Future<bool> postTrip(Map<String, dynamic> payload) async {
    try {
      final base = await resolveBaseUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/trips'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetches trips from the backend, optionally filtered by the EXACT route.
  ///
  /// When [from] / [to] are provided they are sent as `?from=...&to=...`
  /// query parameters and the server returns ONLY trips created for that
  /// exact route (from_location + to_location), so the passenger main screen
  /// never displays trips for another route. Returns an empty list on any
  /// failure so callers never have to handle exceptions.
  static Future<List<Map<String, dynamic>>> fetchTrips({
    String? from,
    String? to,
  }) async {
    try {
      final base = await resolveBaseUrl();
      final f = from?.trim();
      final t = to?.trim();
      final uri = Uri.parse('$base/api/trips').replace(
        queryParameters: {
          if (f != null && f.isNotEmpty) 'from': f,
          if (t != null && t.isNotEmpty) 'to': t,
        },
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final trips = data['trips'] as List<dynamic>? ?? const [];
        return trips
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (_) {
      // ignore — backend offline
    }
    return const [];
  }

  /// Deletes a trip on the backend via REST: `http.delete('$base/api/trips/$tripId')`.
  ///
  /// This is the PRIMARY delete path used when the driver taps delete — it
  /// guarantees the row is removed from the server database (Render), and
  /// the server then broadcasts `trip_deleted` to every connected client.
  /// Returns `true` when the server confirmed the deletion (200/204) or
  /// reports the trip as already gone (404) — both mean the server DB is in
  /// sync. Returns `false` only when the server could not be reached.
  static Future<bool> deleteTrip(String tripId) async {
    try {
      final base = await resolveBaseUrl();
      final response = await http
          .delete(Uri.parse('$base/api/trips/$tripId'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404;
    } catch (_) {
      return false;
    }
  }
}