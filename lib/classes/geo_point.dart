import 'dart:math';

class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint(this.latitude, this.longitude);

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory GeoPoint.fromMap(Map<String, dynamic> map) {
    return GeoPoint(
      map['latitude'] as double,
      map['longitude'] as double,
    );
  }

  @override
  String toString() => 'GeoPoint(latitude: $latitude, longitude: $longitude)';

  double distanceTo(GeoPoint other) {
    const double earthRadius = 6371.0; // Rayon de la Terre en km

    // Conversion en radians
    final lat1 = latitude * (pi / 180);
    final lon1 = longitude * (pi / 180);
    final lat2 = other.latitude * (pi / 180);
    final lon2 = other.longitude * (pi / 180);

    // Formule de Haversine
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}
