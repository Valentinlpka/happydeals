import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class CompanyLocation {
  final String id;
  final String name;
  final String city;
  final GeoPoint location;
  final String address;
  final String postalCode;
  final String country;

  CompanyLocation({
    required this.id,
    required this.name,
    required this.city,
    required this.location,
    required this.address,
    required this.postalCode,
    required this.country,
  });

  factory CompanyLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final addressData = data['adress'] as Map<String, dynamic>? ?? {};

    return CompanyLocation(
      id: doc.id,
      name: data['name'] ?? '',
      city: addressData['ville'] ?? '',
      location: GeoPoint(
        addressData['latitude'] ?? 0,
        addressData['longitude'] ?? 0,
      ),
      address: addressData['adresse'] ?? '',
      postalCode: addressData['code_postal'] ?? '',
      country: addressData['pays']?.toLowerCase() ?? 'france',
    );
  }

  double distanceFromUser(Position userPosition) {
    return Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          location.latitude,
          location.longitude,
        ) /
        1000; // Convertir en kilomètres
  }
}
