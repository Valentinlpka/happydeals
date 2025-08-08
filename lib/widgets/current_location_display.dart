import 'package:flutter/material.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:happy/widgets/unified_location_filter.dart';
import 'package:provider/provider.dart';

class CurrentLocationDisplay extends StatelessWidget {
  final VoidCallback? onLocationChanged;

  const CurrentLocationDisplay({
    super.key,
    this.onLocationChanged,
  });

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        if (!locationProvider.hasLocation) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.location_off,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Localisation non définie',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showLocationFilter(context),
                  child: const Text(
                    'Définir',
                    style: TextStyle(
                      color: Color(0xFF4B88DA),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4B88DA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 16,
                color: Color(0xFF4B88DA),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationProvider.address.isNotEmpty 
                          ? _capitalizeFirstLetter(locationProvider.address)
                          : 'Position actuelle',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B88DA),
                      ),
                    ),
                    Text(
                      'Rayon: ${locationProvider.radius.round()} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showLocationFilter(context),
                child: const Text(
                  'Changer',
                  style: TextStyle(
                    color: Color(0xFF4B88DA),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationFilter(BuildContext context) async {
    await UnifiedLocationFilter.show(
      context: context,
      onLocationChanged: onLocationChanged,
    );
  }
} 