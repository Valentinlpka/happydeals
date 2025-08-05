import 'package:flutter/material.dart';
import 'package:happy/classes/restaurant.dart';
import 'package:happy/providers/restaurant_provider.dart';
import 'package:happy/screens/restaurants/restaurant_detail_page.dart';
import 'package:provider/provider.dart';

class RestaurantDetailWrapper extends StatefulWidget {
  final String restaurantId;

  const RestaurantDetailWrapper({
    super.key,
    required this.restaurantId,
  });

  @override
  State<RestaurantDetailWrapper> createState() => _RestaurantDetailWrapperState();
}

class _RestaurantDetailWrapperState extends State<RestaurantDetailWrapper> {
  Restaurant? restaurant;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    try {
      final provider = context.read<RestaurantProvider>();
      final loadedRestaurant = await provider.getRestaurantById(widget.restaurantId);
      
      if (mounted) {
        setState(() {
          restaurant = loadedRestaurant;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Impossible de charger le restaurant';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null || restaurant == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erreur'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                error ?? 'Restaurant non trouvé',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return RestaurantDetailPage(restaurant: restaurant!);
  }
} 