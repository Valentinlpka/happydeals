import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:happy/classes/category_product.dart';
import 'package:happy/models/french_city.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/match_market/match_market_swipe_page.dart';
import 'package:provider/provider.dart';

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

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

  // Couleurs personnalisées
  final Color primaryColor = const Color(0xFF6C63FF);
  final Color secondaryColor = const Color(0xFFFF6584);
  final Color accentColor = const Color(0xFF00D1FF);
  final Color backgroundColor = const Color(0xFFF8F9FF);

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
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

      if (!mounted) return;
      final userProvider = Provider.of<UserModel>(context, listen: false);
      FrenchCity? userCity;

      userCity = cities.firstWhere(
        (city) => city.label.toLowerCase() == userProvider.city.toLowerCase(),
        orElse: () => FrenchCity(
          inseeCode: '0',
          cityCode: userProvider.city,
          zipCode: '00000',
          label: userProvider.city,
          latitude: userProvider.latitude,
          longitude: userProvider.longitude,
          departmentName: '',
          departmentNumber: '',
          regionName: '',
        ),
      );

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
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Fond animé
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withAlpha(26),
                  secondaryColor.withAlpha(26),
                ],
              ),
            ),
          ),

          // Contenu principal
          SafeArea(
            child: Column(
              children: [
                // En-tête personnalisé
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                'Définissez votre zone',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sélectionnez votre ville et le rayon de recherche',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                if (_isLoading)
                  Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _buildCityCard(),
                          if (_selectedCity != null) ...[
                            const SizedBox(height: 24),
                            _buildRadiusCard(),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedCity != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildCityCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showCitySearchScreen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withAlpha(26),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on,
                  size: 24,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ville de recherche',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedCity?.label.capitalize() ??
                          'Sélectionner une ville',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _selectedCity != null
                            ? primaryColor
                            : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: primaryColor.withAlpha(26 * 5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadiusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(26),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.radar,
                  size: 24,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Rayon de recherche',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedRadius.round()} km',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: primaryColor.withAlpha(20),
              thumbColor: primaryColor,
              overlayColor: primaryColor.withAlpha(22),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 12,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 24,
              ),
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
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withAlpha(26),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ville sélectionnée :',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedCity!.label.capitalize(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withAlpha(26 * 3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchMarketSwipePage(
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
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Commencer la recherche',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 20,
          )
        ],
      ),
    );
  }
}

class CitySearchScreen extends StatefulWidget {
  final List<FrenchCity> cities;

  const CitySearchScreen({super.key, required this.cities});

  @override
  State<CitySearchScreen> createState() => _CitySearchScreenState();
}

class _CitySearchScreenState extends State<CitySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FrenchCity> _filteredCities = [];

  // Couleurs personnalisées
  final Color primaryColor = const Color(0xFF6C63FF);
  final Color secondaryColor = const Color(0xFFFF6584);
  final Color backgroundColor = const Color(0xFFF8F9FF);

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
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Fond animé
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withAlpha(26),
                  secondaryColor.withAlpha(26),
                ],
              ),
            ),
          ),

          // Contenu principal
          SafeArea(
            child: Column(
              children: [
                // En-tête personnalisé
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                'Rechercher une ville',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Entrez le nom d\'une ville ou un code postal',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(26),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Ex: Paris, 75000, Île-de-France',
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Message d'aide ou résultats
                Expanded(
                  child: _searchController.text.length < 2
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: primaryColor.withAlpha(26),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.search,
                                  size: 48,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 24),
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
                        )
                      : _filteredCities.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withAlpha(20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_off,
                                      size: 48,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _filteredCities.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: Colors.grey[200],
                              ),
                              itemBuilder: (context, index) {
                                final city = _filteredCities[index];
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context, city);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withAlpha(26),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.location_city,
                                              color: primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  city.label.capitalize(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${city.zipCode} - ${city.departmentName.toUpperCase()}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: primaryColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
