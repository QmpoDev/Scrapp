// GeofenceService — wraps Haversine distance calculation and geofence check
// Uses WGS-84 mean Earth radius of 6,371,000 metres

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Geofence_Radius: maximum allowed distance (metres) between the user's GPS
/// position and the placed Pin at submission time.
const double kGeofenceRadius = 50.0;

/// Service that computes Haversine great-circle distances and enforces the
/// 50-metre geofence required by Requirements 5.2, 5.3, and 5.6.
abstract final class GeofenceService {
  /// WGS-84 mean Earth radius in metres.
  static const double _earthRadiusMetres = 6371000.0;

  /// Returns the great-circle distance in **metres** between [a] and [b]
  /// using the Haversine formula.
  ///
  /// Valid input ranges: lat ∈ [−90, 90], lng ∈ [−180, 180].
  static double haversineDistance(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;

    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);

    final haversine =
        sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;

    return _earthRadiusMetres *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }

  /// Returns `true` if [current] is within [kGeofenceRadius] metres of [pin]
  /// (i.e. distance < 50 m), `false` otherwise.
  ///
  /// Requirement 5.3: distance must be **strictly less than** 50 metres to pass.
  static bool checkGeofence(LatLng pin, LatLng current) {
    return haversineDistance(pin, current) < kGeofenceRadius;
  }
}
