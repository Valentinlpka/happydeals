import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:happy/classes/category_product.dart';
import 'package:happy/models/french_city.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/match_market/match_market_swipe_page.dart';
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : Stack(
              children: [
                // Fond animé
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor..withAlpha(26),
                        secondaryColor..withAlpha(26),
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
                                  Text(
                                    'Localisation',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'Définissez votre zone de recherche',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Carte de sélection de ville
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _showCitySearchScreen,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    primaryColor..withAlpha(26),
                                    secondaryColor..withAlpha(26),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryColor.withAlpha(52),
                                  width: 2,
                                ),
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
                                      Icons.location_on,
                                      color: primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          _selectedCity?.label ??
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
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Carte de la ville sélectionnée
                      if (_selectedCity != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withAlpha(26),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
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
                                        color: primaryColor.withAlpha(26),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_city,
                                        color: primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
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
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedCity!.zipCode.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withAlpha(26),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.map,
                                          color: primaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        '${_selectedCity!.zipCode} - ${_selectedCity!.departmentName.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Carte du rayon de recherche
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withAlpha(26),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
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
                                        color: primaryColor.withAlpha(26),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.radar,
                                        color: primaryColor,
                                        size: 24,
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
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            primaryColor,
                                            secondaryColor
                                          ],
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
                                    inactiveTrackColor: primaryColor
                                      ..withAlpha(20),
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
                          ),
                        ),

                        const Spacer(),

                        // Bouton de validation
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withAlpha(76),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    'Commencer la recherche',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
                            Text(
                              'Rechercher une ville',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              'Entrez le nom d\'une ville ou un code postal',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(26),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
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
                          borderRadius: BorderRadius.circular(20),
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
                                                  city.label.toUpperCase(),
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
