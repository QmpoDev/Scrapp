import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Haversine great-circle distance. Extracted from MapScreen so it's testable
/// without a widget tree.
abstract final class GeoDistance {
  static const double _earthRadiusKm = 6371.0;

  static double km(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;

    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);

    final haversine =
        sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;

    return _earthRadiusKm *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }
}
