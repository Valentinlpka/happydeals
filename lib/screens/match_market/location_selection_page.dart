import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/category_product.dart';
import 'package:happy/screens/match_market/match_market_swipe_page.dart';

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
  final TextEditingController _cityController = TextEditingController();
  double _radius = 50.0; // Rayon par défaut en km
  bool _isLoading = false;
  String? _error;

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Les services de localisation sont désactivés.';
          _isLoading = false;
        });
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Les permissions de localisation sont refusées.';
            _isLoading = false;
          });
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error =
              'Les permissions de localisation sont définitivement refusées.';
          _isLoading = false;
        });
        return null;
      }

      final position = await Geolocator.getCurrentPosition();
      print(position);
      setState(() {
        _isLoading = false;
      });
      return position;
    } catch (e) {
      setState(() {
        _error = 'Erreur lors de la récupération de la position.';
        _isLoading = false;
      });
      return null;
    }
  }

  void _navigateToSwipePage(Position? position) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MatchMarketSwipePage(
          category: widget.category,
          userPosition: position,
          searchRadius: _radius,
          citySearch:
              _cityController.text.isNotEmpty ? _cityController.text : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Localisation'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Définissez votre zone de recherche',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Ville (optionnel)',
                hintText: 'Entrez une ville',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Rayon de recherche',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            Slider(
              value: _radius,
              min: 5,
              max: 100,
              divisions: 19,
              label: '${_radius.round()} km',
              onChanged: (value) {
                setState(() {
                  _radius = value;
                });
              },
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_cityController.text.isEmpty) {
                        final position = await _getCurrentLocation();
                        _navigateToSwipePage(position);
                      } else {
                        _navigateToSwipePage(null);
                      }
                    },
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_cityController.text.isEmpty
                  ? 'Utiliser ma position'
                  : 'Rechercher'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }
}
