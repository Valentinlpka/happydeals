import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:http/http.dart' as http;

class WebAddressSearch extends StatefulWidget {
  final HomeProvider homeProvider;
  final VoidCallback onLocationUpdated;

  const WebAddressSearch({
    super.key,
    required this.homeProvider,
    required this.onLocationUpdated,
  });

  @override
  _WebAddressSearchState createState() => _WebAddressSearchState();
}

class _WebAddressSearchState extends State<WebAddressSearch> {
  List<Map<String, dynamic>> _predictions = [];
  final String mapboxAccessToken =
      'pk.eyJ1IjoiaGFwcHlkZWFscyIsImEiOiJjbHo3ZHA5NDYwN2hyMnFzNTdiMWd2Zm92In0.1nmT5Fumjq16InZ3dmG9zQ';

  Future<void> _getAddressPredictions(String input) async {
    if (input.length < 3) return;

    final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$input.json?access_token=$mapboxAccessToken&country=FR&types=place,locality&limit=5');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(data['features']);
        });
      } else {}
    } catch (e) {}
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    widget.homeProvider.addressController.text = place['place_name'] ?? '';

    final coordinates = place['geometry']['coordinates'];
    final prediction = Prediction(
      description: place['place_name'],
      placeId: place['id'],
      lat: coordinates[1].toString(),
      lng: coordinates[0].toString(),
    );

    await widget.homeProvider.updateLocationFromPrediction(prediction);
    widget.onLocationUpdated();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 0,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: widget.homeProvider.addressController,
            decoration: InputDecoration(
              hintText: "Rechercher une ville",
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              _getAddressPredictions(value);
            },
          ),
        ),
        if (_predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 0,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return ListTile(
                    title: Text(prediction['place_name'] ?? ''),
                    onTap: () async {
                      await _selectPlace(prediction);
                      setState(() {
                        _predictions = [];
                      });
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
