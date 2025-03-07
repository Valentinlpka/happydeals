import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:happy/classes/category_product.dart';
import 'package:happy/models/french_city.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/match_market/match_market_swipe_page.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:provider/provider.dart';

class LocationSelectionPage extends StatefulWidget {
  final Category category;

  const LocationSelectionPage({
    super.key,
    required this.category,
  });

  @override
  State<LocationSelectionPage> createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  final List<FrenchCity> _allCities = [];
  FrenchCity? _selectedCity;
  double _selectedRadius = 15.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      // Charger les villes depuis le JSON
      final String jsonString =
          await rootBundle.loadString('assets/french_cities.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      final citiesList = data['cities'] as List;

      final List<FrenchCity> cities = [];
      for (var cityJson in citiesList) {
        try {
          cities.add(FrenchCity.fromJson(cityJson));
        } catch (e) {
          continue;
        }
      }

      // Récupérer la ville de l'utilisateur depuis le provider
      final userProvider = Provider.of<UserModel>(context, listen: false);
      FrenchCity? userCity;

      if (userProvider.city != null &&
          userProvider.latitude != null &&
          userProvider.longitude != null) {
        // Chercher la ville dans la liste ou créer une ville personnalisée
        userCity = cities.firstWhere(
          (city) =>
              city.label.toLowerCase() == userProvider.city!.toLowerCase(),
          orElse: () => FrenchCity(
            inseeCode: '0',
            cityCode: userProvider.city!,
            zipCode: '00000',
            label: userProvider.city!,
            latitude: userProvider.latitude!,
            longitude: userProvider.longitude!,
            departmentName: '',
            departmentNumber: '',
            regionName: '',
          ),
        );
      }

      setState(() {
        _allCities.clear();
        _allCities.addAll(cities);
        _selectedCity = userCity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCitySearchScreen() async {
    final selectedCity = await Navigator.push<FrenchCity>(
      context,
      MaterialPageRoute(
        builder: (context) => CitySearchScreen(cities: _allCities),
      ),
    );

    if (selectedCity != null) {
      setState(() {
        _selectedCity = selectedCity;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarBack(
        title: 'Localisation',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // En-tête avec image de fond
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 50,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Où chercher des produits ?',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Définissez votre zone de recherche',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Contenu principal
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bouton de recherche de ville
                        InkWell(
                          onTap: _showCitySearchScreen,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedCity?.label ??
                                        'Rechercher une ville...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _selectedCity != null
                                          ? Colors.black
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Affichage de la ville sélectionnée
                        if (_selectedCity != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_city,
                                      color: Theme.of(context).primaryColor,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ville sélectionnée',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _selectedCity!.label.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedCity!.zipCode.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.map,
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.7),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${_selectedCity!.zipCode} - ${_selectedCity!.departmentName.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Rayon de recherche
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.radar,
                                      color: Theme.of(context).primaryColor,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Rayon de recherche',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '5 km',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_selectedRadius.round()} km',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '50 km',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor:
                                        Theme.of(context).primaryColor,
                                    thumbColor: Theme.of(context).primaryColor,
                                    overlayColor: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.2),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: _selectedRadius,
                                    min: 5,
                                    max: 50,
                                    divisions: 9,
                                    onChanged: (value) {
                                      setState(() => _selectedRadius = value);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Bouton de validation
                          ElevatedButton(
                            onPressed: _selectedCity == null
                                ? null
                                : () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MatchMarketSwipePage(
                                          category: widget.category,
                                          latitude: _selectedCity!.latitude,
                                          longitude: _selectedCity!.longitude,
                                          searchRadius: _selectedRadius,
                                          cityName: _selectedCity!.label,
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 2,
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search),
                                SizedBox(width: 8),
                                Text(
                                  'Commencer la recherche',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Écran de recherche de ville séparé
class CitySearchScreen extends StatefulWidget {
  final List<FrenchCity> cities;

  const CitySearchScreen({super.key, required this.cities});

  @override
  State<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends State<CitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FrenchCity> _filteredCities = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCities);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCities() {
    final query = _searchController.text;

    if (query.length < 2) {
      setState(() {
        _filteredCities = [];
      });
      return;
    }

    final normalizedQuery = _normalizeString(query);

    setState(() {
      _filteredCities = widget.cities
          .where((city) {
            final normalizedLabel = _normalizeString(city.label);
            final normalizedZip = city.zipCode;
            final normalizedDepartment = _normalizeString(city.departmentName);

            return normalizedLabel.contains(normalizedQuery) ||
                normalizedZip.contains(normalizedQuery) ||
                normalizedDepartment.contains(normalizedQuery);
          })
          .take(20)
          .toList();
    });
  }

  String _normalizeString(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[ïî]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher une ville'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Entrez le nom d\'une ville ou un code postal',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),

          // Message d'aide
          if (_searchController.text.length < 2)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Entrez au moins 2 caractères\npour rechercher une ville',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Résultats de recherche
          if (_searchController.text.length >= 2)
            Expanded(
              child: _filteredCities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune ville trouvée',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: _filteredCities.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey[200],
                      ),
                      itemBuilder: (context, index) {
                        final city = _filteredCities[index];
                        return ListTile(
                          title: Text(
                            city.label.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            '${city.zipCode} - ${city.departmentName.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, city);
                          },
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
