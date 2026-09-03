import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  /// The user can override it (see [setCustomBaseUrl]) so a physical phone
  /// can point at the PC's LAN IP instead of the emulator-only mapping below.

  /// - Android emulator: `10.0.2.2` maps to the host machine's `localhost`.
  /// - Everything else (web, desktop, iOS simulator): `localhost`.
  static const String _baseUrlPrefsKey = 'backend_url';
  static String? _customBaseUrl;
  ///   On a physical device this needs the PC's LAN IP — edit here if needed.
  static String _platformDefault() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
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

  /// Saves a custom server address (e.g. `http://192.168.43.59:5000`).
  /// An empty value resets to the platform default (emulator mapping / localhost).
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
      cleaned = 'http://$cleaned';
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

  /// Fetches all active trips from the backend. Returns an empty list on any
  /// failure so callers never have to handle exceptions.
  static Future<List<Map<String, dynamic>>> fetchTrips() async {
    try {
      final base = await resolveBaseUrl();
      final response = await http
          .get(Uri.parse('$base/api/trips'))
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
}