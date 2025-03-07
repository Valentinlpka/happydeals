import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class CompanyLocation {
  final String id;
  final String name;
  final String city;
  final GeoPoint location;

  CompanyLocation({
    required this.id,
    required this.name,
    required this.city,
    required this.location,
  });

  factory CompanyLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final address = data['adress'] as Map<String, dynamic>;

    return CompanyLocation(
      id: doc.id,
      name: data['name'] ?? '',
      city: address['ville'] ?? '',
      location: GeoPoint(
        address['latitude'] as double,
        address['longitude'] as double,
      ),
    );
  }

  double distanceFromPoint(double lat, double lng) {
    return Geolocator.distanceBetween(
          lat,
          lng,
          location.latitude,
          location.longitude,
        ) /
        1000;
  }
}
