import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:provider/provider.dart';

class City {
  final String name;
  final String postalCode;
  final double latitude;
  final double longitude;

  City({
    required this.name,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'],
      postalCode: json['postalCode'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}

class NearbyEntitiesPage extends StatefulWidget {
  const NearbyEntitiesPage({super.key});

  @override
  State<NearbyEntitiesPage> createState() => _NearbyEntitiesPageState();
}

class _NearbyEntitiesPageState extends State<NearbyEntitiesPage> {
  List<City> _allCities = [];
  List<City> _filteredCities = [];
  City? _selectedCity;
  bool _isLoading = true;
  List<Map<String, dynamic>> _nearbyCompanies = [];
  List<Map<String, dynamic>> _nearbyAssociations = [];
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCities();
    _checkLocationAndLoadEntities();
  }

  Future<void> _loadCities() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/french_cities.json');
      final data = json.decode(jsonString);
      _allCities = (data['cities'] as List)
          .map((cityJson) => City.fromJson(cityJson))
          .toList();
    } catch (e) {
      debugPrint('Erreur lors du chargement des villes: $e');
    }
  }

  Future<void> _checkLocationAndLoadEntities() async {
    try {
      // Vérifier si le service de localisation est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      // Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      // Récupérer la position actuelle
      Position position = await Geolocator.getCurrentPosition();

      // Mettre à jour la position dans le UserModel
      final userProvider = Provider.of<UserModel>(context, listen: false);
      await userProvider.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Charger les entités proches
      await _loadNearbyEntities(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la position: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNearbyEntities(double latitude, double longitude) async {
    try {
      // Charger les entreprises proches
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companys')
          .where('type', isNotEqualTo: 'association')
          .where('isActive', isEqualTo: true)
          .get();

      final associationsSnapshot = await FirebaseFirestore.instance
          .collection('companys')
          .where('type', isEqualTo: 'association')
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _nearbyCompanies = companiesSnapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        _nearbyAssociations = associationsSnapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des entités: $e');
    }
  }

  void _filterCities(String query) {
    setState(() {
      _filteredCities = _allCities
          .where((city) =>
              city.name.toLowerCase().contains(query.toLowerCase()) ||
              city.postalCode.contains(query))
          .toList();
    });
  }

  void _selectCity(City city) {
    setState(() {
      _selectedCity = city;
      _cityController.text = '${city.name} (${city.postalCode})';
      _loadNearbyEntities(city.latitude, city.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entités proches'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une ville',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: _filterCities,
                    onTap: () {
                      setState(() {
                        _filteredCities = _allCities;
                      });
                    },
                  ),
                ),
                if (_filteredCities.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredCities.length,
                      itemBuilder: (context, index) {
                        final city = _filteredCities[index];
                        return ListTile(
                          title: Text(city.name),
                          subtitle: Text(city.postalCode),
                          onTap: () => _selectCity(city),
                        );
                      },
                    ),
                  ),
                if (_selectedCity != null)
                  Expanded(
                    child: ListView(
                      children: [
                        if (_nearbyCompanies.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Entreprises proches',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ..._nearbyCompanies.map((company) => ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: company['logo'] != null &&
                                          company['logo'].isNotEmpty
                                      ? NetworkImage(company['logo'])
                                      : null,
                                  child: company['logo'] == null ||
                                          company['logo'].isEmpty
                                      ? const Icon(Icons.business)
                                      : null,
                                ),
                                title: Text(company['name'] ?? ''),
                                subtitle: Text(company['categorie'] ?? ''),
                                onTap: () {
                                  // TODO: Naviguer vers la page de l'entreprise
                                },
                              )),
                        ],
                        if (_nearbyAssociations.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Associations proches',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ..._nearbyAssociations.map((association) => ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      association['logo'] != null &&
                                              association['logo'].isNotEmpty
                                          ? NetworkImage(association['logo'])
                                          : null,
                                  child: association['logo'] == null ||
                                          association['logo'].isEmpty
                                      ? const Icon(Icons.people)
                                      : null,
                                ),
                                title: Text(association['name'] ?? ''),
                                subtitle:
                                    Text(association['description'] ?? ''),
                                onTap: () {
                                  // TODO: Naviguer vers la page de l'association
                                },
                              )),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
