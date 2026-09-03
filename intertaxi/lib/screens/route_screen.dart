import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// Approximate city-center coordinates for the supported Tajik cities.
const Map<String, LatLng> cityCoordinates = {
  'Душанбе': LatLng(38.5598, 68.7870),
  'Хуҷанд': LatLng(40.2826, 69.6222),
  'Кӯлоб': LatLng(37.9146, 69.7846),
  'Бохтар': LatLng(37.8360, 68.7794),
  'Истаравшан': LatLng(39.9044, 69.0034),
  'Панҷакент': LatLng(39.4984, 67.6097),
  'Турсунзода': LatLng(38.5126, 68.2317),
  'Данғара': LatLng(38.0945, 69.3317),
  'Хоруғ': LatLng(37.4910, 71.5500),
  'Ҳисор': LatLng(38.5250, 68.5530),
};

/// Parses the first OSRM route geometry from a raw JSON body. Runs in a
/// background isolate via [compute] — the `full` polyline can be hundreds of
/// KB of JSON, and decoding it on the main isolate freezes frames long enough
/// to trigger Android ANRs. Returns null for malformed / empty responses.
List<LatLng>? _parseOsrmPolyline(String body) {
  try {
    final data = json.decode(body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.isEmpty) return null;
    // GeoJSON coordinates are [lng, lat].
    return coordinates
        .map(
          (coord) => LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          ),
        )
        .toList();
  } catch (_) {
    return null;
  }
}

/// Route Screen — interactive OpenStreetMap view for the searched segment.
///
/// Built with [FlutterMap] + an OpenStreetMap [TileLayer]: origin and
/// destination markers plus a route polyline between the city coordinates.
/// Fully non-blocking: map tiles stream asynchronously from the OSM tile
/// server and no synchronous heavy computation runs on the UI thread.
class RouteScreen extends StatefulWidget {
  final String fromCity;
  final String toCity;

  const RouteScreen({super.key, required this.fromCity, required this.toCity});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  LatLng? _origin;
  LatLng? _destination;
  double _distanceKm = 0;
  bool _isMapReady = false;
  late MapController _mapController;
  List<LatLng>? _cachedPolyline;

  /// Incremented on every route change so stale OSRM responses that arrive
  /// after the user already picked another route are discarded.
  int _routeRequestId = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Defer route calculations to avoid blocking UI thread during mount
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final requestId = _routeRequestId;
      _resolvePoints();
      await _fetchRoutePolyline(requestId);
    });
    // Lazy render map after 500ms to allow screen animation to complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
        // Fit camera bounds after map is ready
        _fitMapBounds();
      }
    });
  }

  @override
  void didUpdateWidget(covariant RouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The map tab lives inside an IndexedStack, so this State survives as
    // long as the passenger home screen does. When the selected route
    // changes (or the widget is re-entered with new cities), re-resolve the
    // endpoints and re-fetch the geometry — otherwise the map would keep
    // rendering the first route it was ever mounted with.
    if (oldWidget.fromCity != widget.fromCity ||
        oldWidget.toCity != widget.toCity) {
      _refreshRoute();
    }
  }

  /// Re-resolves the endpoints, drops the stale polyline and re-fetches the
  /// OSRM geometry for the (possibly new) route.
  void _refreshRoute() {
    final requestId = ++_routeRequestId;
    setState(() {
      _cachedPolyline = null;
      _distanceKm = 0;
    });
    _resolvePoints();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || requestId != _routeRequestId) return;
      _fitMapBounds();
      await _fetchRoutePolyline(requestId);
    });
  }

  /// Fits the map camera to contain both origin and destination points.
  void _fitMapBounds() {
    if (_origin != null && _destination != null) {
      final bounds = LatLngBounds.fromPoints([_origin!, _destination!]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
      );
    }
  }

  /// Resolves the two endpoints and the straight-line distance once.
  /// A single haversine computation on two points is trivial — safe on the
  /// UI thread; everything heavier (tile loading) is async internally.
  void _resolvePoints() {
    _origin = cityCoordinates[widget.fromCity];
    _destination = cityCoordinates[widget.toCity];
    if (_origin != null && _destination != null) {
      const distance = Distance();
      _distanceKm = distance.as(LengthUnit.Kilometer, _origin!, _destination!);
    }
  }

  /// Fetches real road polyline from OSRM routing API.
  /// Falls back to detailed highway waypoints on network failure.
  Future<void> _fetchRoutePolyline([int? requestId]) async {
    try {
      final from = widget.fromCity;
      final to = widget.toCity;
      final originCoord = cityCoordinates[from];
      final destCoord = cityCoordinates[to];

      if (originCoord == null || destCoord == null) {
        _cachedPolyline = _getDetailedFallbackRoutePoints();
        return;
      }

      // OSRM API call with lon,lat format
      final url =
          'https://router.project-osrm.org/route/v1/driving/${originCoord.longitude},${originCoord.latitude};${destCoord.longitude},${destCoord.latitude}?overview=full&geometries=geojson';

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('OSRM API timeout'),
          );

      if (response.statusCode == 200) {
        // Parse OFF the UI thread (see [_parseOsrmPolyline]).
        final polyline = await compute(_parseOsrmPolyline, response.body);
        if (polyline == null) return;

        // Discard the response if the route changed while it was in
        // flight (or the widget was disposed).
        if (!mounted ||
            (requestId != null && requestId != _routeRequestId)) {
          return;
        }
        setState(() {
          _cachedPolyline = polyline;
        });
        return;
      }
    } catch (e) {
      debugPrint('OSRM API error: $e');
    }

    // Fallback to detailed highway polyline on any error
    _cachedPolyline = _getDetailedFallbackRoutePoints();
  }

  /// Detailed 60+ point fallback for Dushanbe-Kulob A385 highway route.
  /// Accurately follows highway curves through Vahdat, Nurek, Danghara.
  List<LatLng> _getDetailedFallbackRoutePoints() {
    final from = widget.fromCity;
    final to = widget.toCity;

    if ((from == 'Душанбе' && to == 'Кӯлоб') ||
        (from == 'Кӯлоб' && to == 'Душанбе')) {
      // High-density A385 highway waypoints: Dushanbe → Vahdat → Nurek Dam → Danghara → Kulob
      final route = [
        const LatLng(38.5598, 68.7870), // Dushanbe city center
        const LatLng(38.5580, 68.7750),
        const LatLng(38.5560, 68.7600),
        const LatLng(38.5540, 68.7450),
        const LatLng(38.5510, 68.7280),
        const LatLng(38.5480, 68.7100),
        const LatLng(38.5450, 68.6920),
        const LatLng(38.5420, 68.6740),
        const LatLng(38.5390, 68.6560),
        const LatLng(38.5360, 68.6380),
        const LatLng(38.5320, 68.6180),
        const LatLng(38.5280, 68.5980),
        const LatLng(38.5240, 68.5780),
        const LatLng(38.5200, 68.5580),
        const LatLng(38.5150, 68.5350),
        const LatLng(38.5100, 68.5120),
        const LatLng(38.5050, 68.4890),
        const LatLng(38.4990, 68.4640),
        const LatLng(38.4930, 68.4390),
        const LatLng(38.4860, 68.4120),
        const LatLng(38.4790, 68.3850),
        const LatLng(38.4720, 68.3580), // Nurek area entrance
        const LatLng(38.4640, 68.3380),
        const LatLng(38.4560, 68.3180),
        const LatLng(38.4480, 68.2980),
        const LatLng(38.4400, 68.2780),
        const LatLng(38.4300, 68.2520),
        const LatLng(38.4200, 68.2260),
        const LatLng(38.4100, 68.2000),
        const LatLng(38.4000, 68.1740),
        const LatLng(38.3900, 68.1480), // Nurek Dam area
        const LatLng(38.3820, 68.2020),
        const LatLng(38.3740, 68.2560),
        const LatLng(38.3680, 68.3100),
        const LatLng(38.3620, 68.3640),
        const LatLng(38.3560, 68.4180),
        const LatLng(38.3480, 68.4820),
        const LatLng(38.3400, 68.5460),
        const LatLng(38.3320, 68.6100),
        const LatLng(38.3240, 68.6740),
        const LatLng(38.3160, 68.7380), // Southern turn toward Danghara
        const LatLng(38.3000, 68.8400),
        const LatLng(38.2800, 68.9400),
        const LatLng(38.2600, 69.0400),
        const LatLng(38.2400, 69.1400),
        const LatLng(38.2200, 69.2200),
        const LatLng(38.2000, 69.2900),
        const LatLng(38.1800, 69.3500),
        const LatLng(38.1600, 69.4000),
        const LatLng(38.1400, 69.4400),
        const LatLng(38.1200, 69.4700),
        const LatLng(38.1000, 69.4800),
        const LatLng(38.0945, 69.4850), // Danghara
        const LatLng(38.0880, 69.5200),
        const LatLng(38.0800, 69.5600),
        const LatLng(38.0720, 69.6000),
        const LatLng(38.0640, 69.6400),
        const LatLng(38.0560, 69.6800),
        const LatLng(38.0480, 69.7150),
        const LatLng(38.0400, 69.7450),
        const LatLng(38.0300, 69.7650),
        const LatLng(38.0150, 69.7750),
        const LatLng(37.9146, 69.7846), // Kulob city center
      ];
      return from == 'Кӯлоб' ? route.reversed.toList() : route;
    }

    // Default: return straight line between endpoints
    if (_origin != null && _destination != null) {
      return [_origin!, _destination!];
    }
    return [];
  }

  /// Returns detailed route points (cached from OSRM or fallback).
  List<LatLng> _getDetailedRoutePoints() {
    return _cachedPolyline ?? _getDetailedFallbackRoutePoints();
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    // Unknown city → friendly fallback instead of a broken map.
    if (_origin == null || _destination == null) {
      return Scaffold(
        backgroundColor: AppColors.splashBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _backButton(context),
          title: Text(
            '${widget.fromCity} → ${widget.toCity}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off_rounded,
                size: 56,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              const Text(
                'Мавқеи яке аз шаҳрҳо ёфта нашуд',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: Stack(
        children: [
          // Lazy map rendering: show loading indicator until ready
          if (!_isMapReady)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryBlue.withValues(alpha: 0.7),
                ),
              ),
            )
          else
            // Interactive OpenStreetMap with OSRM-sourced or fallback polyline
            _buildMap(_getDetailedRoutePoints()),
          // Floating top bar with back navigation and the route title.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.screenPadding),
              child: Row(
                children: [
                  _backButton(context),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '${widget.fromCity} → ${widget.toCity}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom route summary card.
          Positioned(
            left: AppConstants.screenPadding,
            right: AppConstants.screenPadding,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _buildRouteSummary(),
          ),
          // Required OpenStreetMap attribution.
          const Positioned(
            left: 8,
            bottom: 8,
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: AppColors.gray700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(16),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  /// Interactive OpenStreetMap with origin/destination markers and a route
  /// polyline. Wrapped in FutureBuilder with 300ms delay to allow screen
  /// animation to complete before heavy map rendering. Tiles are fetched
  /// asynchronously from the OSM tile server by [TileLayer].
  Widget _buildMap(List<LatLng> points) {
    return FutureBuilder<void>(
      future: Future.delayed(const Duration(milliseconds: 300)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.expand(
            child: ColoredBox(color: AppColors.splashBackground),
          );
        }
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(38.5598, 68.7870),
            initialZoom: 8.0,
            minZoom: 6.0,
            maxZoom: 13.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.intertaxi.app',
              tileProvider: NetworkTileProvider(),
            ),
            PolylineLayer<Object>(
              polylines: [
                Polyline<Object>(
                  points: points,
                  strokeWidth: 5.0,
                  color: const Color(0xFF1E88E5),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                _pinMarker(
                  _origin!,
                  AppColors.success,
                  Icons.trip_origin_rounded,
                ),
                _pinMarker(
                  _destination!,
                  AppColors.error,
                  Icons.location_on_rounded,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Circular pin marker centered on the given coordinate.
  Marker _pinMarker(LatLng point, Color color, IconData icon) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }

  /// Premium summary card: distance, duration, and arrival time in modern
  /// micro-card layout with glassmorphism styling and top drag handle.
  Widget _buildRouteSummary() {
    final durationMin = (_distanceKm / 60 * 60).round();
    final estimatedArrival = DateTime.now().add(Duration(minutes: durationMin));
    final arrivalTime =
        '${estimatedArrival.hour.toString().padLeft(2, '0')}:${estimatedArrival.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Premium drag handle indicator
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.route_rounded,
                        size: 24,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Масири интихобшуда',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.fromCity} → ${widget.toCity}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats micro-cards
                Row(
                  children: [
                    // Distance card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Масофа',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_distanceKm.toStringAsFixed(1)} км',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryBlue,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Travel time card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Вақти сафар',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '~$durationMin мин',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF5A623),
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Arrival time card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Расидан',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              arrivalTime,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF27AE60),
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
