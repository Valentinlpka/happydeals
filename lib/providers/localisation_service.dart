import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static const _googleApiKey = "AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc";

  // Méthode unifiée pour obtenir l'adresse à partir des coordonnées
  static Future<Map<String, dynamic>> getLocationFromCoordinates(
      double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleApiKey&language=fr&result_type=locality',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        final components = data['results'][0]['address_components'];
        String? city;
        String? country;

        for (var component in components) {
          final types = component['types'] as List;
          if (types.contains('locality')) {
            city = component['long_name'];
          } else if (types.contains('country')) {
            country = component['long_name'];
          }
        }

        if (city != null) {
          return {
            'address': country != null ? '$city, $country' : city,
            'latitude': lat,
            'longitude': lng,
          };
        }
      }

      // Fallback avec geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (place.locality?.isNotEmpty ?? false) {
          return {
            'address': place.country?.isNotEmpty ?? false
                ? '${place.locality}, ${place.country}'
                : place.locality!,
            'latitude': lat,
            'longitude': lng,
          };
        }
      }

      return {
        'address': 'Position ($lat, $lng)',
        'latitude': lat,
        'longitude': lng,
      };
    } catch (e) {
      print('Erreur dans getLocationFromCoordinates: $e');
      return {
        'address': 'Position ($lat, $lng)',
        'latitude': lat,
        'longitude': lng,
      };
    }
  }

  // Méthode unifiée pour obtenir les coordonnées à partir d'une prédiction Google Places
  static Future<Map<String, dynamic>> getLocationFromPrediction(
      Prediction prediction) async {
    if (prediction.lat == null || prediction.lng == null) {
      throw Exception('Coordonnées manquantes dans la prédiction');
    }

    final lat = double.parse(prediction.lat!);
    final lng = double.parse(prediction.lng!);

    return {
      'address': prediction.description ?? '',
      'latitude': lat,
      'longitude': lng,
    };
  }
}
