import 'package:flutter_test/flutter_test.dart';
import 'package:intertaxi/screens/passenger_home_screen.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test(
    'RouteProgressEstimator returns remaining metrics for a valid route',
    () {
      final route = [
        const LatLng(38.5598, 68.7870),
        const LatLng(38.5605, 68.7895),
        const LatLng(38.5625, 68.7920),
        const LatLng(38.5650, 68.7955),
        const LatLng(38.5700, 68.8000),
      ];

      final progress = RouteProgressEstimator.estimate(
        user: const LatLng(38.5620, 68.7910),
        route: route,
        destination: const LatLng(38.5700, 68.8000),
        totalRouteMeters: 1200,
        totalRouteSeconds: 240,
      );

      expect(progress, isNotNull);
      expect(progress!.remainingMeters, greaterThan(0));
      expect(progress.remainingSeconds, greaterThan(0));
    },
  );
}
