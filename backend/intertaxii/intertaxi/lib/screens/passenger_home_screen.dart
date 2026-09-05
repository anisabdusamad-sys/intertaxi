import 'dart:async';

import 'dart:convert';

import 'dart:math' as math;



import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart' show compute;

import 'package:flutter_map/flutter_map.dart';

import 'package:flutter_tts/flutter_tts.dart';

import 'package:geolocator/geolocator.dart';

import 'package:latlong2/latlong.dart';

import 'package:http/http.dart' as http;



import '../models/driver_ride_model.dart';

import '../models/intertaxi_models.dart' as models;

import '../services/api_service.dart';

import '../widgets/city_selection_modal.dart';

import '../widgets/driver_ride_card.dart';

import 'all_ads_screen.dart';

import 'profile_screen.dart';

import 'route_screen.dart';

import 'trip_detail_screen.dart';



/// Center point and zoom level for the Масир map tab, kept as top-level

/// constants so the camera always frames Tajikistan on first paint.

const LatLng kTajikistanCenter = LatLng(38.5598, 68.7870);

const double kTajikistanZoom = 8.0;

/// Result of parsing an OSRM route response in a background isolate.
class _ParsedOsrmRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  const _ParsedOsrmRoute(
    this.points,
    this.distanceMeters,
    this.durationSeconds,
  );
}

/// Parses the first OSRM route (geometry + distance + duration) from a raw
/// JSON body. Runs in a background isolate via [compute] — the `full`
/// geometry of a long route can be hundreds of KB of JSON, and decoding it
/// on the main isolate freezes frames long enough to trigger Android ANRs.
/// Returns null for malformed / empty responses.
_ParsedOsrmRoute? _parseOsrmRouteResponse(String body) {
  try {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.isEmpty) return null;
    // GeoJSON coordinates are [lng, lat] — convert to LatLng.
    final points = coordinates
        .map(
          (coordinate) => LatLng(
            ((coordinate as List<dynamic>)[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ),
        )
        .toList();
    return _ParsedOsrmRoute(
      points,
      (route['distance'] as num?)?.toDouble() ?? 0,
      (route['duration'] as num?)?.toDouble() ?? 0,
    );
  } catch (_) {
    return null;
  }
}



/// InterTaxi Passenger Home Screen

/// Full passenger interface with bottom navigation

class PassengerHomeScreen extends StatefulWidget {

  final String passengerName;

  final String passengerPhone;



  const PassengerHomeScreen({

    super.key,

    required this.passengerName,

    required this.passengerPhone,

  });



  @override

  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();

}



/// Coordinates of the cities served by InterTaxi, used to place route

/// markers on the Масир (map) tab. Values match the app-wide city list.

const Map<String, LatLng> _cityCoordinates = {

  'Кӯлоб': LatLng(37.9146, 69.7845),

  'Душанбе': LatLng(38.5598, 68.7870),

  'Восеъ': LatLng(37.8031, 69.6453),

  'Хуҷанд': LatLng(40.2833, 69.6333),

  'Бухоро': LatLng(39.7681, 64.4556),

  'Самарқанд': LatLng(39.6542, 66.9597),

  'Файзобод': LatLng(38.5481, 69.3167),

  'Турсунзода': LatLng(38.5111, 68.2317),

  'Панҷакент': LatLng(39.4952, 67.6093),

  'Истаравшан': LatLng(39.9142, 69.0033),

};



/// Cached OSRM route geometry and stats for a city pair.

class _OsrmRoute {

  final List<LatLng> points;

  final double distanceMeters;

  final double durationSeconds;



  const _OsrmRoute({

    required this.points,

    required this.distanceMeters,

    required this.durationSeconds,

  });

}



/// Pure route-progress estimator used to evaluate the remaining distance and

/// ETA without executing a large scan during every widget build.

class RouteProgressEstimator {

  static const double _earthRadius = 6371000.0;



  static double _degToRad(double degrees) => degrees * math.pi / 180;



  static double _haversineMeters(LatLng a, LatLng b) {

    final dLat = _degToRad(b.latitude - a.latitude);

    final dLng = _degToRad(b.longitude - a.longitude);

    final lat1 = _degToRad(a.latitude);

    final lat2 = _degToRad(b.latitude);

    final haversine =

        math.sin(dLat / 2) * math.sin(dLat / 2) +

        math.cos(lat1) *

            math.cos(lat2) *

            math.sin(dLng / 2) *

            math.sin(dLng / 2);

    return _earthRadius *

        2 *

        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));

  }



  static ({double remainingMeters, double remainingSeconds})? estimate({

    required LatLng user,

    required List<LatLng> route,

    required LatLng destination,

    double totalRouteMeters = 0,

    double totalRouteSeconds = 0,

    double routeSnapThreshold = 1500,

  }) {

    if (route.isEmpty) return null;



    var nearestIndex = 0;

    var nearestDistance = double.infinity;

    for (var i = 0; i < route.length; i++) {

      final currentDistance = _haversineMeters(user, route[i]);

      if (currentDistance < nearestDistance) {

        nearestDistance = currentDistance;

        nearestIndex = i;

      }

    }



    if (nearestDistance > routeSnapThreshold) return null;



    var remainingMeters = nearestDistance;

    for (var i = nearestIndex; i < route.length - 1; i++) {

      remainingMeters += _haversineMeters(route[i], route[i + 1]);

    }

    remainingMeters += _haversineMeters(route.last, destination);



    if (remainingMeters <= 0) return null;



    final effectiveTotalMeters = totalRouteMeters > 0

        ? totalRouteMeters

        : remainingMeters;

    final effectiveSpeed = totalRouteSeconds > 0

        ? effectiveTotalMeters / totalRouteSeconds

        : 12.0;

    if (effectiveSpeed <= 0) return null;



    return (

      remainingMeters: remainingMeters,

      remainingSeconds: remainingMeters / effectiveSpeed,

    );

  }

}



class _PassengerHomeScreenState extends State<PassengerHomeScreen> {

  int _currentIndex = 0;

  /// Incremented every time the "Все объявления" tab is re-opened so the
  /// screen is recreated (fresh Key) and reloads the latest driver ads.
  int _adsTabEpoch = 0;

  /// Tabs are mounted lazily: an [IndexedStack] builds ALL of its children
  /// on the first frame even when they are hidden. Building the full map
  /// tab (flutter_map + polyline) together with every other tab in a single
  /// frame blocks the UI thread long enough to trigger Android ANRs
  /// ("Приложение не отвечает"). Each heavy tab is therefore only mounted
  /// the first time the user opens it and stays alive afterwards, so its
  /// state is still preserved between tab switches.
  final Set<int> _mountedTabs = {0};

  bool _isLoading = true;



  /// Controls the OpenStreetMap camera on the Масир tab.

  final MapController _mapController = MapController();



  /// Voice assistant used to announce the ride summary aloud.

  final FlutterTts _flutterTts = FlutterTts();



  /// In-memory cache of fetched OSRM routes, keyed "from->to", so switching

  /// tabs never re-triggers network requests for the same pair.

  final Map<String, _OsrmRoute> _routeGeometryCache = {};



  /// Key of the route currently rendered / being fetched ("from->to").

  String? _activeRouteKey;



  /// Driving geometry (actual road path) of the active route, once fetched.

  List<LatLng> _activeGeometry = const [];



  /// Active route stats from OSRM (meters / seconds).

  double _activeDistance = 0;

  double _activeDuration = 0;



  /// Ignore stale/irrelevant GPS fixes that are far from the route line.

  static const double _routeSnapThreshold = 1500;



  /// Whether an OSRM route request is currently in flight.

  bool _isLoadingRouteGeometry = false;



  // ==================== LIVE GPS TRACKING STATE ====================

  /// Active GPS position stream subscription (geolocator).

  StreamSubscription<Position>? _positionSubscription;



  /// Latest device GPS fix, rendered as the live user/driver marker.

  Position? _currentPosition;



  /// Cached route-progress values to avoid repeating expensive nearest-point

  /// scans during each widget rebuild. This is recomputed only on GPS updates.

  ({double remainingMeters, double remainingSeconds})? _routeProgress;



  /// Tracks the last progress recomputation timestamp to keep GPS-driven UI

  /// updates under the frame budget.

  DateTime? _lastProgressUpdateAt;



  /// Whether the GPS position stream is active.

  bool _isTracking = false;



  /// Whether the map camera follows the live user position.

  final bool _followUser = true;



  @override

  void initState() {

    super.initState();

    _fromCity = 'Душанбе';

    _toCity = 'Кӯлоб';



    // Defer all heavy computations until after the first frame to prevent ANR

    WidgetsBinding.instance.addPostFrameCallback((_) async {

      if (!mounted) return;

      try {

        // Load driving route geometry and map state

        await _loadDrivingRoute();

        if (!mounted) return;

        _focusMapOnRoute();

      } catch (_) {

        // Silently fail and continue — route will render as straight line

      } finally {

        // Mark loading complete

        if (mounted) {

          setState(() => _isLoading = false);

        }

      }

    });

  }



  @override

  void dispose() {

    _positionSubscription?.cancel();

    _flutterTts.stop();

    // Tear down every piece of in-memory session state so that re-entering
    // the passenger section always starts from a clean slate (no stale
    // route cache, no previous search results, no leftover route selection).
    _routeGeometryCache.clear();

    _activeRouteKey = null;

    _activeGeometry = const [];

    _activeDistance = 0;

    _activeDuration = 0;

    _routeProgress = null;

    _currentPosition = null;

    _isTracking = false;

    _hasSearched = false;

    _searchError = false;

    _searchResults = [];

    super.dispose();

  }



  // ==================== ROUTE SEARCH STATE ====================

  String? _fromCity;

  String? _toCity;

bool _isSearching = false;

  bool _hasSearched = false;

  bool _searchError = false;

  List<DriverRide> _searchResults = [];



  @override

  Widget build(BuildContext context) {

    // While loading, show lightweight skeleton UI to prevent ANR

    if (_isLoading && _currentIndex != 2) {

      return Scaffold(

        backgroundColor: Colors.white,

        body: SafeArea(

          child: Column(

            children: [

              Expanded(

                child: SingleChildScrollView(

                  padding: const EdgeInsets.all(24),

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const SizedBox(height: 16),

                      // Quick skeleton greeting

                      Container(

                        height: 40,

                        width: 200,

                        decoration: BoxDecoration(

                          color: Colors.grey[200],

                          borderRadius: BorderRadius.circular(8),

                        ),

                      ),

                      const SizedBox(height: 32),

                      // Skeleton search card

                      Container(

                        width: double.infinity,

                        height: 280,

                        decoration: BoxDecoration(

                          color: Colors.grey[200],

                          borderRadius: BorderRadius.circular(24),

                        ),

                      ),

                    ],

                  ),

                ),

              ),

              _buildBottomNavigation(),

            ],

          ),

        ),

      );

    }



    // Full UI once loading completes

    return Scaffold(

      backgroundColor: Colors.white,

      body: SafeArea(

        child: Column(

          children: [

            Expanded(

              child: IndexedStack(

                index: _currentIndex,

                children: [

                  _buildHomeTab(),

                  // Heavy tabs are mounted on first visit only (see
                  // _mountedTabs) so the first frame stays lightweight.
                  _mountedTabs.contains(1)
                      ? _buildAdsTab()
                      : const SizedBox.shrink(),

                  _mountedTabs.contains(2)
                      ? _buildMapTab()
                      : const SizedBox.shrink(),

                  _mountedTabs.contains(3)
                      ? _buildMessagesTab()
                      : const SizedBox.shrink(),

                  _mountedTabs.contains(4)
                      ? _buildProfileTab()
                      : const SizedBox.shrink(),

                ],

              ),

            ),

            _buildBottomNavigation(),

          ],

        ),

      ),

    );

  }



  // ==================== HOME TAB ====================

  Widget _buildHomeTab() {

    return SingleChildScrollView(

      padding: const EdgeInsets.all(24),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const SizedBox(height: 16),

          Row(

            children: [

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      'Салом, ${widget.passengerName}!',

                      style: const TextStyle(

                        fontSize: 24,

                        fontWeight: FontWeight.bold,

                        color: Colors.black87,

                      ),

                    ),

                    const SizedBox(height: 4),

                    Text(

                      'Ба куҷо меравем?',

                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),

                    ),

                  ],

                ),

              ),

              const Icon(

                Icons.account_circle_rounded,

                size: 48,

                color: Color(0xFF0066FF),

              ),

            ],

          ),

          const SizedBox(height: 24),



          // Search card

          Container(

            width: double.infinity,

            padding: const EdgeInsets.all(20),

            decoration: BoxDecoration(

              gradient: const LinearGradient(

                colors: [Color(0xFF1E56EC), Color(0xFF0B309A)],

                begin: Alignment.topLeft,

                end: Alignment.bottomRight,

              ),

              borderRadius: BorderRadius.circular(24),

              boxShadow: [

                BoxShadow(

                  color: const Color(0xFF1E56EC).withValues(alpha: 0.35),

                  blurRadius: 24,

                  offset: const Offset(0, 10),

                ),

              ],

            ),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Icon(

                  Icons.local_taxi_rounded,

                  size: 48,

                  color: Colors.white,

                ),

                const SizedBox(height: 16),

                const Text(

                  'Ҷустуҷӯи мошин',

                  style: TextStyle(

                    fontSize: 20,

                    fontWeight: FontWeight.bold,

                    color: Colors.white,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  'Мошинро барои сафар пайдо кунед',

                  style: TextStyle(fontSize: 13, color: Colors.white70),

                ),

                const SizedBox(height: 16),



                // From / To location inputs — frosted glass panel with a

                // dashed route connector between origin and destination.

                Container(

                  padding: const EdgeInsets.symmetric(

                    horizontal: 16,

                    vertical: 10,

                  ),

                  decoration: BoxDecoration(

                    color: Colors.white.withValues(alpha: 0.15),

                    borderRadius: BorderRadius.circular(14),

                    border: Border.all(color: Colors.white24),

                  ),

                  child: Column(

                    children: [

                      _buildLocationRow(

                        icon: Icons.trip_origin_rounded,

                        color: Colors.greenAccent,

                        label: 'Аз куҷо меравед?',

                        selectedValue: _fromCity,

                        onTap: () => _showCityPicker(isFrom: true),

                      ),

                      // Dashed vertical route line between the two pins.

                      Padding(

                        padding: const EdgeInsets.only(left: 9),

                        child: Column(

                          children: List.generate(

                            4,

                            (index) => Container(

                              width: 2,

                              height: 4,

                              margin: const EdgeInsets.symmetric(vertical: 2),

                              decoration: BoxDecoration(

                                color: Colors.white38,

                                borderRadius: BorderRadius.circular(1),

                              ),

                            ),

                          ),

                        ),

                      ),

                      _buildLocationRow(

                        icon: Icons.location_on_rounded,

                        color: Colors.redAccent,

                        label: 'Ба куҷо рафтан мехоҳед?',

                        selectedValue: _toCity,

                        onTap: () => _showCityPicker(isFrom: false),

                      ),

                    ],

                  ),

                ),



                const SizedBox(height: 16),

                Container(

                  width: double.infinity,

                  height: 50,

                  decoration: BoxDecoration(

                    borderRadius: BorderRadius.circular(14),

                    boxShadow: const [

                      BoxShadow(

                        color: Colors.black12,

                        blurRadius: 12,

                        offset: Offset(0, 4),

                      ),

                    ],

                  ),

                  child: ElevatedButton.icon(

                    onPressed: _isSearching ? null : _handleSearch,

                    icon: _isSearching

                        ? const SizedBox(

                            width: 18,

                            height: 18,

                            child: CircularProgressIndicator(

                              strokeWidth: 2,

                              color: Color(0xFF1E56EC),

                            ),

                          )

                        : const Icon(Icons.search_rounded),

                    label: Text(

                      _isSearching ? 'Ҷустуҷӯ...' : 'Ҷустуҷӯи мошин',

                      style: const TextStyle(fontWeight: FontWeight.w700),

                    ),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: Colors.white,

                      foregroundColor: const Color(0xFF1E56EC),

                      disabledBackgroundColor: Colors.white.withValues(

                        alpha: 0.7,

                      ),

                      disabledForegroundColor: const Color(

                        0xFF1E56EC,

                      ).withValues(alpha: 0.5),

                      elevation: 0,

                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(14),

                      ),

                    ),

                  ),

                ),

              ],

            ),

          ),



          // Search results (driver list) — rendered below the search card

          _buildSearchResultsSection(),

        ],

      ),

    );

  }



  // ==================== MAP TAB (МАСИР) ====================



  /// True when both route ends are selected and known on the map.

  bool get _hasRoutePoints =>

      _fromCity != null &&

      _toCity != null &&

      _cityCoordinates.containsKey(_fromCity) &&

      _cityCoordinates.containsKey(_toCity);



  /// The two route endpoints used for the map polyline.

  List<LatLng> get _routePoints => [

    _cityCoordinates[_fromCity!]!,

    _cityCoordinates[_toCity!]!,

  ];



  // ==================== LIVE GPS TRACKING ====================



  /// Starts streaming the device GPS position (requesting permission if

  /// needed) so the user marker, remaining stats and camera stay live.

  Future<void> _startLocationTracking() async {

    if (_isTracking || _positionSubscription != null) return;



    // Wrap entire operation in timeout to prevent any GPS hang from freezing the UI

    try {

      await _initializeGpsWithTimeout();

    } catch (_) {

      // Any error or timeout — silently ignore and let stream below deliver updates

    }



    _positionSubscription =

        Geolocator.getPositionStream(

          locationSettings: const LocationSettings(

            accuracy: LocationAccuracy.high,

            distanceFilter: 10,

          ),

        ).listen(

          _onPositionUpdate,

          onError: (error) {

            // GPS stream error — silently ignore and continue.

            if (!mounted) return;

            // Position updates will resume when GPS is available again.

          },

        );

  }



  /// Initializes GPS with strict timeout to prevent UI hangs.

  Future<void> _initializeGpsWithTimeout() async {

    await Future.delayed(Duration.zero); // Yield to event loop



    var permission = await Geolocator.checkPermission().timeout(

      const Duration(seconds: 3),

      onTimeout: () => LocationPermission.denied,

    );



    if (permission == LocationPermission.denied) {

      permission = await Geolocator.requestPermission().timeout(

        const Duration(seconds: 5),

        onTimeout: () => LocationPermission.denied,

      );

    }



    if (permission == LocationPermission.denied ||

        permission == LocationPermission.deniedForever) {

      return;

    }



    // Initial fix so the marker appears immediately.

    try {

      final position = await Geolocator.getCurrentPosition(

        locationSettings: const LocationSettings(

          accuracy: LocationAccuracy.high,

        ),

      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      setState(() {

        _currentPosition = position;

        _isTracking = true;

      });

      _followUserOnMap(position);

    } catch (_) {

      // Position unavailable or timeout — the stream below will still deliver.

    }

  }



  /// Handles each live GPS update: moves the user marker, follows the

  /// camera and recomputes remaining distance / time / arrival without doing

  /// route scanning in the widget build path.

  void _onPositionUpdate(Position position) {

    if (!mounted) return;



    _currentPosition = position;

    if (_followUser) _followUserOnMap(position);



    final now = DateTime.now();

    final shouldRefresh =

        _lastProgressUpdateAt == null ||

        now.difference(_lastProgressUpdateAt!) >=

            const Duration(milliseconds: 250);



    if (!shouldRefresh) return;



    _lastProgressUpdateAt = now;

    final route = _activeGeometry.isNotEmpty ? _activeGeometry : _routePoints;

    if (!_hasRoutePoints || route.isEmpty) {

      setState(() => _routeProgress = null);

      return;

    }



    final progress = RouteProgressEstimator.estimate(

      user: LatLng(position.latitude, position.longitude),

      route: route,

      destination: _cityCoordinates[_toCity!]!,

      totalRouteMeters: _activeDistance,

      totalRouteSeconds: _activeDuration,

    );



    setState(() => _routeProgress = progress);

  }



  /// Keeps the map camera centered on the user without changing zoom.

  void _followUserOnMap(Position position) {

    _mapController.move(

      LatLng(position.latitude, position.longitude),

      _mapController.camera.zoom,

    );

  }



  /// Speaks a short route summary using the system TTS engine.

  Future<void> _speakTripSummary() async {

    if (_fromCity == null || _toCity == null) return;



    final origin = _fromCity!;

    final destination = _toCity!;

    final totalDistanceKm = _activeDistance > 0 ? _activeDistance / 1000 : 0.0;

    final totalMinutes = _activeDuration > 0

        ? (_activeDuration / 60).round()

        : 0;

    final hours = totalMinutes ~/ 60;

    final minutes = totalMinutes % 60;



    String distanceText;

    if (totalDistanceKm >= 1) {

      distanceText = totalDistanceKm.toStringAsFixed(

        totalDistanceKm < 10 ? 1 : 0,

      );

    } else {

      distanceText = '${_activeDistance.round()}';

    }



    final durationText = hours > 0 && minutes > 0

        ? '$hours соат $minutes дақиқа'

        : hours > 0

        ? '$hours соат'

        : minutes > 0

        ? '$minutes дақиқа'

        : '0 дақиқа';



    final speech =

        'Салом! Хуш омадед ба барномаи InterTaxi. Шумо аз $origin ба $destination меравед. '

        'Масофаи умумӣ $distanceText километр буда, вақти сафар тахминан $durationText '

        'ро ташкил медиҳад. Сафари хуш!';



    try {

      await _flutterTts.setLanguage('tg-TJ');

      await _flutterTts.setSpeechRate(0.9);

      await _flutterTts.setVolume(1.0);

      await _flutterTts.setPitch(1.0);

      await _flutterTts.speak(speech);

    } catch (_) {

      // Ignore TTS engine incompatibility; the UI should remain responsive.

    }

  }



  /// Great-circle distance between two points, in meters.

  double _haversineMeters(LatLng a, LatLng b) {

    const earthRadius = 6371000.0;

    final dLat = _degToRad(b.latitude - a.latitude);

    final dLng = _degToRad(b.longitude - a.longitude);

    final lat1 = _degToRad(a.latitude);

    final lat2 = _degToRad(b.latitude);

    final h =

        math.sin(dLat / 2) * math.sin(dLat / 2) +

        math.cos(lat1) *

            math.cos(lat2) *

            math.sin(dLng / 2) *

            math.sin(dLng / 2);

    return earthRadius * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));

  }



  double _degToRad(double degrees) => degrees * math.pi / 180;



  /// Remaining distance/time to the destination from the live position,

  /// measured along the route polyline. Returns null while tracking has no

  /// GPS fix yet or no route is active.

  ({double remainingMeters, double remainingSeconds})? _computeRemaining() {

    final position = _currentPosition;

    if (position == null || !_hasRoutePoints) return null;



    final path = _activeGeometry.isNotEmpty ? _activeGeometry : _routePoints;

    final destination = _cityCoordinates[_toCity!]!;



    return RouteProgressEstimator.estimate(

      user: LatLng(position.latitude, position.longitude),

      route: path,

      destination: destination,

      totalRouteMeters: _activeDistance,

      totalRouteSeconds: _activeDuration,

      routeSnapThreshold: _routeSnapThreshold,

    );

  }



  /// Fits the map camera on the active route — the full road geometry when

  /// it has been fetched, otherwise the two endpoints. Scheduled after the

  /// frame so the map is laid out with its final size.

  void _focusMapOnRoute() {

    final coords = <LatLng>[

      ...(_activeGeometry.isNotEmpty

          ? _activeGeometry

          : <LatLng>[

              if (_fromCity != null && _cityCoordinates.containsKey(_fromCity))

                _cityCoordinates[_fromCity!]!,

              if (_toCity != null && _cityCoordinates.containsKey(_toCity))

                _cityCoordinates[_toCity!]!,

            ]),

    ];

    if (coords.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!mounted) return;

      _mapController.fitCamera(

        CameraFit.coordinates(

          coordinates: coords,

          padding: const EdgeInsets.all(80),

        ),

      );

    });

  }



  /// Fetches the real driving route geometry from the free OSRM public

  /// routing API and caches it in memory per city pair, so switching tabs

  /// never re-triggers the network request. Falls back to a straight line

  /// between the cities while loading / if the request fails.

  Future<void> _loadDrivingRoute() async {

    if (!_hasRoutePoints) return;

    final key = '$_fromCity->$_toCity';



    // Already rendered for this pair, or a request is already in flight.

    if (_activeRouteKey == key && _activeGeometry.isNotEmpty) return;

    if (_isLoadingRouteGeometry) return;



    // Serve instantly from the in-memory cache.

    final cached = _routeGeometryCache[key];

    if (cached != null) {

      setState(() {

        _activeRouteKey = key;

        _activeGeometry = cached.points;

        _activeDistance = cached.distanceMeters;

        _activeDuration = cached.durationSeconds;

        _isLoadingRouteGeometry = false;

      });

      _focusMapOnRoute();

      return;

    }



    setState(() {

      _activeRouteKey = key;

      _activeGeometry = const [];

      _activeDistance = 0;

      _activeDuration = 0;

      _isLoadingRouteGeometry = true;

    });



    final start = _cityCoordinates[_fromCity!]!;

    final end = _cityCoordinates[_toCity!]!;

    final url = Uri.parse(

      'https://router.project-osrm.org/route/v1/driving/'

      '${start.longitude},${start.latitude};'

      '${end.longitude},${end.latitude}'

      '?overview=full&geometries=geojson',

    );



    try {

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      // Parse OFF the UI thread (see [_parseOsrmRouteResponse]).

      final parsed = response.statusCode == 200
          ? await compute(_parseOsrmRouteResponse, response.body)
          : null;

      if (!mounted) return;

      if (parsed != null) {

        _routeGeometryCache[key] = _OsrmRoute(

          points: parsed.points,

          distanceMeters: parsed.distanceMeters,

          durationSeconds: parsed.durationSeconds,

        );

        setState(() {

          _activeGeometry = parsed.points;

          _activeDistance = parsed.distanceMeters;

          _activeDuration = parsed.durationSeconds;

          _isLoadingRouteGeometry = false;

          _routeProgress = RouteProgressEstimator.estimate(

            user: _currentPosition == null

                ? const LatLng(38.5598, 68.7870)

                : LatLng(

                    _currentPosition!.latitude,

                    _currentPosition!.longitude,

                  ),

            route: parsed.points,

            destination: _cityCoordinates[_toCity!]!,

            totalRouteMeters: parsed.distanceMeters,

            totalRouteSeconds: parsed.durationSeconds,

            routeSnapThreshold: _routeSnapThreshold,

          );

        });

        _focusMapOnRoute();

        return;

      }

      // Malformed response → keep the straight-line fallback, allow retry.

      setState(() {

        _isLoadingRouteGeometry = false;

        _activeDistance = 0;

        _activeDuration = 0;

        _activeRouteKey = null;

      });

    } catch (_) {

      // Network failure → keep the straight-line fallback, allow retry.

      if (!mounted) return;

      setState(() {

        _isLoadingRouteGeometry = false;

        _activeDistance = 0;

        _activeDuration = 0;

        _activeRouteKey = null;

      });

    }

  }



  /// The Масир tab: displays the premium RouteScreen with selected route

  /// (fromCity → toCity) showing interactive map, markers, and route summary.

  Widget _buildMapTab() {

    final fromCity = _fromCity ?? 'Душанбе';

    final toCity = _toCity ?? 'Кӯлоб';

    return RouteScreen(fromCity: fromCity, toCity: toCity);

  }



  /// Route markers drawn on the map: green = origin, red = destination.

  List<Marker> _buildRouteMarkers() {

    final markers = <Marker>[];

    if (_fromCity != null && _cityCoordinates.containsKey(_fromCity)) {

      markers.add(

        Marker(

          point: _cityCoordinates[_fromCity!]!,

          width: 44,

          height: 44,

          child: Container(

            decoration: BoxDecoration(

              color: Colors.green,

              shape: BoxShape.circle,

              border: Border.all(color: Colors.white, width: 3),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withValues(alpha: 0.25),

                  blurRadius: 6,

                  offset: const Offset(0, 2),

                ),

              ],

            ),

            child: const Icon(

              Icons.trip_origin_rounded,

              size: 20,

              color: Colors.white,

            ),

          ),

        ),

      );

    }

    if (_toCity != null && _cityCoordinates.containsKey(_toCity)) {

      markers.add(

        Marker(

          point: _cityCoordinates[_toCity!]!,

          width: 44,

          height: 44,

          child: Container(

            decoration: BoxDecoration(

              color: Colors.red,

              shape: BoxShape.circle,

              border: Border.all(color: Colors.white, width: 3),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withValues(alpha: 0.25),

                  blurRadius: 6,

                  offset: const Offset(0, 2),

                ),

              ],

            ),

            child: const Icon(

              Icons.location_on_rounded,

              size: 20,

              color: Colors.white,

            ),

          ),

        ),

      );

    }

    // Live user/driver position marker.

    final position = _currentPosition;

    if (position != null) {

      markers.add(

        Marker(

          point: LatLng(position.latitude, position.longitude),

          width: 44,

          height: 44,

          child: Container(

            decoration: BoxDecoration(

              color: Colors.white,

              shape: BoxShape.circle,

              border: Border.all(color: const Color(0xFF1E56EC), width: 3),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withValues(alpha: 0.25),

                  blurRadius: 6,

                  offset: const Offset(0, 2),

                ),

              ],

            ),

            child: const Icon(

              Icons.navigation_rounded,

              size: 20,

              color: Color(0xFF1E56EC),

            ),

          ),

        ),

      );

    }

    return markers;

  }



  /// Small floating card over the map: the tab title and the selected route

  /// (or a hint when nothing is selected yet).

  Widget _buildMapHeaderCard() {

    final hasRoute = _fromCity != null && _toCity != null;

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(16),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.08),

            blurRadius: 12,

            offset: const Offset(0, 4),

          ),

        ],

      ),

      child: Row(

        children: [

          Container(

            width: 42,

            height: 42,

            decoration: BoxDecoration(

              color: const Color(0xFF0066FF).withValues(alpha: 0.08),

              borderRadius: BorderRadius.circular(12),

            ),

            child: const Icon(

              Icons.route_rounded,

              size: 22,

              color: Color(0xFF0066FF),

            ),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Text(

                  'Масир',

                  style: TextStyle(

                    fontSize: 16,

                    fontWeight: FontWeight.w700,

                    color: Colors.black87,

                  ),

                ),

                const SizedBox(height: 2),

                Text(

                  hasRoute

                      ? '$_fromCity → $_toCity'

                      : 'Масирро дар саҳифаи «Асосӣ» интихоб кунед',

                  style: TextStyle(

                    fontSize: 12,

                    color: hasRoute

                        ? const Color(0xFF0066FF)

                        : Colors.grey[600],

                    fontWeight: hasRoute ? FontWeight.w600 : FontWeight.normal,

                  ),

                ),

              ],

            ),

          ),

          // Route loading indicator while OSRM geometry is being fetched.

          if (_isLoadingRouteGeometry)

            const Padding(

              padding: EdgeInsets.only(left: 8),

              child: SizedBox(

                width: 16,

                height: 16,

                child: CircularProgressIndicator(

                  strokeWidth: 2,

                  color: Color(0xFF1E56EC),

                ),

              ),

            ),

        ],

      ),

    );

  }



  /// Formats OSRM meters as a short distance label (e.g. "185 км").

  String _formatDistance(double meters) {

    if (meters <= 0) return '—';

    if (meters >= 1000) {

      final km = meters / 1000;

      return '${km.toStringAsFixed(km < 10 ? 1 : 0)} км';

    }

    return '${meters.round()} м';

  }



  /// Formats OSRM seconds as a duration label (e.g. "2 соат 30 дақ").

  String _formatDuration(double seconds) {

    if (seconds <= 0) return '—';

    final totalMinutes = (seconds / 60).round();

    final hours = totalMinutes ~/ 60;

    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) return '$hours соат $minutes дақ';

    if (hours > 0) return '$hours соат';

    return '$minutes дақ';

  }



  /// Estimated arrival time from now (e.g. "~11:35").

  String _formatArrival(double seconds) {

    if (seconds <= 0) return '—';

    final arrival = DateTime.now().add(Duration(seconds: seconds.round()));

    final hour = arrival.hour.toString().padLeft(2, '0');

    final minute = arrival.minute.toString().padLeft(2, '0');

    return '~$hour:$minute';

  }



  /// Premium floating stats card: distance, trip time and arrival, each in

  /// an icon chip with blue accents, arranged horizontally.

  Widget _buildRouteStatsCard() {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.12),

            blurRadius: 20,

            offset: const Offset(0, 6),

          ),

        ],

      ),

      child: Builder(

        builder: (context) {

          // Default to the total OSRM route figures; only show remaining

          // distance/time after a valid live GPS position has moved onto the route.

          final bool hasOsrmTotals = _activeDistance > 0 && _activeDuration > 0;

          final remaining = _routeProgress ?? _computeRemaining();

          final String distanceLabel;

          final String distanceValue;

          final String durationLabel;

          final String durationValue;

          final String arrivalValue;

          if (remaining != null &&

              remaining.remainingMeters > 0 &&

              remaining.remainingSeconds > 0) {

            distanceLabel = 'Масофаи монда';

            distanceValue =

                '${_formatDistance(remaining.remainingMeters)} монд';

            durationLabel = 'Вақти монда';

            durationValue =

                '${_formatDuration(remaining.remainingSeconds)} монд';

            arrivalValue = _formatArrival(remaining.remainingSeconds);

          } else {

            distanceLabel = 'Масофа';

            distanceValue = hasOsrmTotals

                ? _formatDistance(_activeDistance)

                : '—';

            durationLabel = 'Вақти сафар';

            durationValue = hasOsrmTotals

                ? _formatDuration(_activeDuration)

                : '—';

            arrivalValue = hasOsrmTotals

                ? _formatArrival(_activeDuration)

                : '—';

          }

          return Row(

            children: [

              _buildStatChip(

                icon: Icons.route_rounded,

                label: distanceLabel,

                value: distanceValue,

              ),

              _buildStatDivider(),

              _buildStatChip(

                icon: Icons.schedule_rounded,

                label: durationLabel,

                value: durationValue,

              ),

              _buildStatDivider(),

              _buildStatChip(

                icon: Icons.flag_rounded,

                label: 'Вақти расидан',

                value: arrivalValue,

              ),

            ],

          );

        },

      ),

    );

  }



  /// Vertical separator between the stat chips.

  Widget _buildStatDivider() {

    return Container(width: 1, height: 40, color: Colors.grey[200]);

  }



  /// A single stat chip: circular blue icon badge + label + bold value.

  Widget _buildStatChip({

    required IconData icon,

    required String label,

    required String value,

  }) {

    return Expanded(

      child: Column(

        children: [

          Container(

            width: 34,

            height: 34,

            decoration: BoxDecoration(

              color: const Color(0xFF1E56EC).withValues(alpha: 0.08),

              shape: BoxShape.circle,

            ),

            child: Icon(icon, size: 18, color: const Color(0xFF1E56EC)),

          ),

          const SizedBox(height: 6),

          Text(

            label,

            style: TextStyle(fontSize: 10, color: Colors.grey[600]),

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

          ),

          const SizedBox(height: 2),

          Text(

            value,

            style: const TextStyle(

              fontSize: 12,

              fontWeight: FontWeight.bold,

              color: Color(0xFF1E56EC),

            ),

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

          ),

        ],

      ),

    );

  }



  Widget _buildLocationRow({

    required IconData icon,

    required String label,

    required Color color,

    String? selectedValue,

    VoidCallback? onTap,

  }) {

    final hasValue = selectedValue != null && selectedValue.isNotEmpty;

    // Styled for the blue gradient card: white text / translucent hints.

    return InkWell(

      onTap: onTap,

      borderRadius: BorderRadius.circular(8),

      child: Padding(

        padding: const EdgeInsets.symmetric(vertical: 8),

        child: Row(

          children: [

            Icon(icon, size: 20, color: color),

            const SizedBox(width: 12),

            Expanded(

              child: Text(

                hasValue ? selectedValue : label,

                style: TextStyle(

                  fontSize: 15,

                  fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,

                  color: hasValue ? Colors.white : Colors.white70,

                ),

              ),

            ),

            if (hasValue)

              const Icon(

                Icons.check_circle_rounded,

                size: 16,

                color: Colors.white,

              ),

            const Icon(

              Icons.arrow_forward_ios_rounded,

              size: 14,

              color: Colors.white54,

            ),

          ],

        ),

      ),

    );

  }



  // ==================== ROUTE SEARCH LOGIC ====================



  /// Opens the city selection modal bottom sheet and stores the result.

  Future<void> _showCityPicker({required bool isFrom}) async {

    final selectedCity = await showCitySelectionSheet(

      context: context,

      title: isFrom ? 'Аз куҷо меравед?' : 'Ба куҷо рафтан мехоҳед?',

      selectedCity: isFrom ? _fromCity : _toCity,

    );

    if (selectedCity == null || !mounted) return;



    setState(() {

      if (isFrom) {

        _fromCity = selectedCity;

        // Keep From/To different — reset the other one if it now duplicates.

        if (_toCity == selectedCity) _toCity = null;

      } else {

        _toCity = selectedCity;

        if (_fromCity == selectedCity) _fromCity = null;

      }

      // Reset previous results when the route changes.

      _hasSearched = false;

      _searchError = false;

      _searchResults = [];

    });



    // Route changes should bind immediately to the map and the OSRM totals.

    _loadDrivingRoute();

    _focusMapOnRoute();

  }



  /// Runs the route search against the backend AND the orders saved on this
  /// device.

  ///

  /// 1. The server (`GET /api/trips?from=...&to=...`) returns ONLY the trips
  ///    drivers created for that exact route, so the main passenger screen
  ///    never displays announcements for another route.

  /// 2. Locally persisted announcements are merged in as a fallback (useful
  ///    while the backend is offline), keeping ONLY rides whose from AND to
  ///    locations PRECISELY match the searched route and still have free
  ///    seats.

  /// Results are sorted: exact matches first, then by departure time.

  Future<void> _handleSearch() async {

    if (_fromCity == null || _toCity == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Лутфан ҷойи оғоз ва таъинро интихоб кунед'),

          behavior: SnackBarBehavior.floating,

        ),

      );

      return;

    }



    setState(() {

      _hasSearched = true;

      _isSearching = true;

      _searchError = false;

      _searchResults = [];

    });

    try {

      final from = _fromCity!;

      final to = _toCity!;

      final rides = <DriverRide>[];

      final seenIds = <String>{};



      // 1) Backend trips, filtered server-side by the EXACT route.

      final serverTrips = await ApiService.fetchTrips(from: from, to: to);

      for (final trip in serverTrips) {

        final ride = DriverRide.fromMap(trip);

        if (ride.availableSeats > 0 && seenIds.add(ride.id)) {

          rides.add(ride);

        }

      }



      // 2) Local announcements as an offline fallback. Only trips whose
      //    from AND to PRECISELY match the search route are kept — an
      //    announcement for a different destination must never appear.

      final orders = await models.loadOrders();

      for (final order in orders) {

        final ride = orderToRide(order);

        if (ride == null) continue;

        if (ride.availableSeats > 0 &&

            ride.isExactMatch(from, to) &&

            seenIds.add(ride.id)) {

          rides.add(ride);

        }

      }



      rides.sort((a, b) {

        final aExact = a.isExactMatch(from, to) ? 0 : 1;

        final bExact = b.isExactMatch(from, to) ? 0 : 1;

        if (aExact != bExact) return aExact - bExact;

        return a.departureTime.compareTo(b.departureTime);

      });

      if (!mounted) return;

      setState(() => _searchResults = rides);

    } catch (_) {

      if (!mounted) return;

      setState(() => _searchError = true);

    } finally {

      if (mounted) setState(() => _isSearching = false);

    }

  }



  /// Results header + scrollable driver list, rendered below the panel.

  Widget _buildSearchResultsSection() {

    if (!_hasSearched) return const SizedBox.shrink();



    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const SizedBox(height: 28),

        Row(

          children: [

            const Text(

              'Ёфтшуда:',

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.bold,

                color: Colors.black87,

              ),

            ),

            const Spacer(),

            Text(

              _isSearching

                  ? 'ҷустуҷӯ...'

                  : _searchResults.isEmpty

                  ? 'Ягон мошин нест'

                  : '${_searchResults.length} мошин',

              style: TextStyle(

                fontSize: 14,

                fontWeight: FontWeight.w600,

                color: _searchResults.isEmpty

                    ? Colors.grey[600]

                    : const Color(0xFF1E56EC),

              ),

            ),

          ],

        ),

        const SizedBox(height: 12),

        if (_isSearching)

          const Padding(

            padding: EdgeInsets.symmetric(vertical: 32),

            child: Center(

              child: CircularProgressIndicator(color: Color(0xFF0066FF)),

            ),

          )

        else if (_searchError)

          Container(

            width: double.infinity,

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(16),

              border: Border.all(color: Colors.grey[200]!, width: 1),

            ),

            child: Column(

              children: [

                Icon(

                  Icons.cloud_off_rounded,

                  size: 48,

                  color: Colors.grey[400],

                ),

                const SizedBox(height: 12),

                const Text(

                  'Хатогӣ дар ҷустуҷӯ',

                  style: TextStyle(

                    fontSize: 16,

                    fontWeight: FontWeight.w600,

                    color: Colors.black87,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  'Боркунии маълумот хомӯш шуд. Бори дигар кӯшиш кунед.',

                  textAlign: TextAlign.center,

                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),

                ),

                const SizedBox(height: 12),

                ElevatedButton.icon(

                  onPressed: _handleSearch,

                  icon: const Icon(Icons.refresh_rounded, size: 18),

                  label: const Text('Аз нав кӯшиш'),

                  style: ElevatedButton.styleFrom(

                    backgroundColor: const Color(0xFF0066FF),

                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(20),

                    ),

                  ),

                ),

              ],

            ),

          )

        else if (_searchResults.isEmpty)

          _buildEmptyStateCard()

        else

          ListView.separated(

            shrinkWrap: true,

            physics: const NeverScrollableScrollPhysics(),

            itemCount: _searchResults.length,

            separatorBuilder: (_, _) => const SizedBox(height: 12),

            itemBuilder: (context, index) {

              final ride = _searchResults[index];

              return DriverRideCard(

                ride: ride,

                searchFrom: _fromCity!,

                searchTo: _toCity!,

                onTap: () {

                  Navigator.of(context).push(

                    MaterialPageRoute(

                      builder: (_) => TripDetailScreen(

                        trip: ride.toMap(),

                        passengerName: widget.passengerName,

                        passengerPhone: widget.passengerPhone,

                      ),

                    ),

                  );

                },

              );

            },

          ),

      ],

    );

  }



  /// Premium empty-state card shown when no cars matched the route:

  /// soft background, icon badge with cross, bold header, and a

  /// try-again action button.

  Widget _buildEmptyStateCard() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),

      decoration: BoxDecoration(

        color: const Color(0xFFF8FAFC),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.grey[200]!),

      ),

      child: Column(

        children: [

          // Icon badge: car with a small "not found" cross badge.

          Container(

            width: 64,

            height: 64,

            decoration: BoxDecoration(

              color: const Color(0xFF1E56EC).withValues(alpha: 0.08),

              shape: BoxShape.circle,

            ),

            child: Stack(

              clipBehavior: Clip.none,

              alignment: Alignment.center,

              children: [

                const Icon(

                  Icons.directions_car_rounded,

                  size: 30,

                  color: Color(0xFF1E56EC),

                ),

                Positioned(

                  right: -2,

                  top: -2,

                  child: Container(

                    width: 16,

                    height: 16,

                    decoration: BoxDecoration(

                      color: Colors.red[400],

                      shape: BoxShape.circle,

                      border: Border.all(

                        color: const Color(0xFFF8FAFC),

                        width: 2,

                      ),

                    ),

                    child: const Icon(

                      Icons.close_rounded,

                      size: 8,

                      color: Colors.white,

                    ),

                  ),

                ),

              ],

            ),

          ),

          const SizedBox(height: 16),

          const Text(

            'Ҳоло дар ин масир ронандае нест',

            textAlign: TextAlign.center,

            style: TextStyle(

              fontSize: 16,

              fontWeight: FontWeight.bold,

              color: Colors.black87,

            ),

          ),

          const SizedBox(height: 4),

          Text(

            'Барои ин масир ҳоло эълони ронандагон вуҷуд надорад. Масири дигарро санҷед.',

            textAlign: TextAlign.center,

            style: TextStyle(

              fontSize: 13,

              color: Colors.grey[600],

              height: 1.5,

            ),

          ),

          const SizedBox(height: 16),

          // Try-again action

          ElevatedButton.icon(

            onPressed: _isSearching ? null : _handleSearch,

            icon: _isSearching

                ? const SizedBox(

                    width: 16,

                    height: 16,

                    child: CircularProgressIndicator(

                      strokeWidth: 2,

                      color: Colors.white,

                    ),

                  )

                : const Icon(Icons.refresh_rounded, size: 18),

            label: Text(

              _isSearching ? 'Ҷустуҷӯ...' : 'Такрор кардан',

              style: const TextStyle(fontWeight: FontWeight.w600),

            ),

            style: ElevatedButton.styleFrom(

              backgroundColor: const Color(0xFF1E56EC),

              foregroundColor: Colors.white,

              elevation: 0,

              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(12),

              ),

            ),

          ),

        ],

      ),

    );

  }



  // ==================== MESSAGES TAB ====================

  Widget _buildMessagesTab() {

    return Center(

      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Icon(Icons.message_rounded, size: 64, color: Colors.grey[400]),

          const SizedBox(height: 16),

          Text(

            'Сообщения',

            style: TextStyle(

              fontSize: 18,

              fontWeight: FontWeight.w600,

              color: Colors.grey[600],

            ),

          ),

          const SizedBox(height: 8),

          Text(

            'Дар ин ҷо паёмҳо пайдо мешаванд',

            style: TextStyle(fontSize: 13, color: Colors.grey[400]),

          ),

        ],

      ),

    );

  }



  // ==================== PROFILE TAB ====================

  Widget _buildProfileTab() {

    return ProfileScreen(

      initialName: widget.passengerName,

      initialPhone: widget.passengerPhone,

    );

  }



  /// The "Все объявления" tab: shows every driver announcement (all orders)
  /// in one place — nothing is filtered by a route here. Using a fresh
  /// [ValueKey] on the epoch counter forces a rebuild + reload every time the
  /// tab is opened.
  Widget _buildAdsTab() {
    return AllAdsScreen(key: ValueKey('ads_tab_$_adsTabEpoch'));
  }



  // ==================== BOTTOM NAVIGATION ====================

  Widget _buildBottomNavigation() {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.05),

            blurRadius: 10,

            offset: const Offset(0, -2),

          ),

        ],

      ),

      child: BottomNavigationBar(

        currentIndex: _currentIndex,

        onTap: (index) {

          setState(() {

            _currentIndex = index;

            // Mount the tab the first time it is opened (lazy loading —
            // see _mountedTabs).
            _mountedTabs.add(index);

            // Refresh the ads list every time the tab is opened again.
            if (index == 1) _adsTabEpoch++;

          });

          if (index == 2) {

            _loadDrivingRoute();

            _focusMapOnRoute();

            // Run GPS tracking in background so UI doesn't freeze while requesting permissions

            Future.microtask(() => _startLocationTracking());

          } else {

            // Pause GPS streaming while the map tab is not visible.

            _positionSubscription?.cancel();

            _positionSubscription = null;

            _isTracking = false;

          }

        },

        type: BottomNavigationBarType.fixed,

        backgroundColor: Colors.white,

        elevation: 0,

        selectedItemColor: const Color(0xFF0066FF),

        unselectedItemColor: Colors.grey[400],

        selectedFontSize: 12,

        unselectedFontSize: 12,

        items: const [

          BottomNavigationBarItem(

            icon: Icon(Icons.home_rounded),

            activeIcon: Icon(Icons.home_rounded, size: 28),

            label: 'Асосӣ',

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.campaign_rounded),

            activeIcon: Icon(Icons.campaign_rounded, size: 28),

            label: 'Все объявления',

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.route_rounded),

            activeIcon: Icon(Icons.route_rounded, size: 28),

            label: 'Масир',

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.message_rounded),

            activeIcon: Icon(Icons.message_rounded, size: 28),

            label: 'Сообщения',

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.person_rounded),

            activeIcon: Icon(Icons.person_rounded, size: 28),

            label: 'Профил',

          ),

        ],

      ),

    );

  }

}

