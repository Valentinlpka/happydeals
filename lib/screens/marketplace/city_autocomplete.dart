import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CityData {
  final String label;

  CityData({required this.label});

  factory CityData.fromJson(Map<String, dynamic> json) {
    return CityData(label: json['label']);
  }
}

Future<List<CityData>> loadCities() async {
  String jsonString = await rootBundle.loadString('assets/french_cities.json');
  Map<String, dynamic> jsonMap = json.decode(jsonString);
  List<dynamic> citiesList = jsonMap['cities'];
  return citiesList.map((city) => CityData.fromJson(city)).toList();
}

String capitalizeWords(String input) {
  if (input.isEmpty) return input;
  return input.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

Widget buildCityTextField(String label, TextEditingController controller) {
  return FutureBuilder<List<CityData>>(
    future: loadCities(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        final allCities = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Autocomplete<CityData>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<CityData>.empty();
                    }
                    return allCities.where((CityData city) {
                      return city.label
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  displayStringForOption: (CityData city) =>
                      capitalizeWords(city.label),
                  onSelected: (CityData selection) {
                    controller.text = capitalizeWords(selection.label);
                  },
                  fieldViewBuilder: (BuildContext context,
                      TextEditingController fieldTextEditingController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted) {
                    return TextFormField(
                      controller: fieldTextEditingController,
                      focusNode: fieldFocusNode,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 16),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      } else {
        return const CircularProgressIndicator();
      }
    },
  );
}
