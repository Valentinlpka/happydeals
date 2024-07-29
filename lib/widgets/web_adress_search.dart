import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:http/http.dart' as http;

class WebAddressSearch extends StatefulWidget {
  final HomeProvider homeProvider;

  const WebAddressSearch({super.key, required this.homeProvider});

  @override
  _WebAddressSearchState createState() => _WebAddressSearchState();
}

class _WebAddressSearchState extends State<WebAddressSearch> {
  List<dynamic> _predictions = [];

  Future<void> _getAddressPredictions(String input) async {
    if (input.length < 3) return;

    const proxyUrl = 'https://cors-anywhere.herokuapp.com/';
    const apiUrl =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    final fullUrl =
        '$proxyUrl$apiUrl?input=$input&types=(cities)&components=country:fr&key=AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc';

    try {
      final response = await http.get(Uri.parse(fullUrl), headers: {
        'Origin':
            'http://localhost', // Remplacez par l'URL de votre application
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _predictions = data['predictions'];
        });
      }
    } catch (e) {
      print('Erreur lors de la récupération des prédictions: $e');
    }
  }

  Future<void> _getPlaceDetails(String placeId) async {
    const proxyUrl = 'https://cors-anywhere.herokuapp.com/';
    const apiUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
    final fullUrl =
        '$proxyUrl$apiUrl?place_id=$placeId&fields=geometry&key=AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc';

    try {
      final response = await http.get(Uri.parse(fullUrl), headers: {
        'Origin':
            'http://localhost', // Remplacez par l'URL de votre application
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] != null && data['result']['geometry'] != null) {
          final location = data['result']['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];

          // Créez un objet Prediction similaire à celui utilisé dans la version mobile
          final prediction = Prediction(
            description: widget.homeProvider.addressController.text,
            placeId: placeId,
            lat: lat.toString(),
            lng: lng.toString(),
          );

          // Mettez à jour la localisation dans le HomeProvider
          widget.homeProvider.updateLocationFromPrediction(prediction);
        }
      }
    } catch (e) {
      print('Erreur lors de la récupération des détails du lieu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.homeProvider.addressController,
          decoration: const InputDecoration(
            hintText: "Rechercher une ville",
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _getAddressPredictions(value);
          },
        ),
        if (_predictions.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return ListTile(
                  title: Text(prediction['description']),
                  onTap: () async {
                    widget.homeProvider.addressController.text =
                        prediction['description'];
                    await _getPlaceDetails(prediction['place_id']);
                    setState(() {
                      _predictions = [];
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
