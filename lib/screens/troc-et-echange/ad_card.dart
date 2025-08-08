import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/geo_point.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:provider/provider.dart';

class AdCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final GeoPoint? userLocation;

  const AdCard({
    super.key,
    required this.ad,
    required this.onTap,
    this.onSaveTap,
    this.userLocation,
  });

  String _formatDistance(double distance) {
    if (distance < 1) {
      return '< 1 km';
    } else if (distance < 10) {
      return '${distance.toStringAsFixed(1)} km';
    } else {
      return '${distance.round()} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SavedAdsProvider>(
      builder: (context, savedAdsProvider, _) {
        final isSaved = savedAdsProvider.isAdSaved(ad.id);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.all(4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image avec badge de sauvegarde
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: Image.network(
                          ad.photos.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  color: Colors.blue[700],
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey[400],
                                  size: 32,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Badge de sauvegarde
                    if (onSaveTap != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: onSaveTap,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isSaved ? Icons.bookmark : Icons.bookmark_border,
                                size: 16,
                                color: isSaved ? Colors.blue[700] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Contenu
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    spacing: 5,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type d'échange
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ad.additionalData['exchangeType'] ?? 'Échange',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Titre
                      Text(
                        ad.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                      // Localisation et distance
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          Expanded(
                            child: Text(
                              _getLocationText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Échange souhaité
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.swap_horiz,
                              size: 12,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                ad.additionalData['wishInReturn'] ?? 'Ouvert aux propositions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLocationText() {
    String locationText = ad.additionalData['cityName'] ?? 'Non spécifié';

    if (userLocation != null && ad.additionalData['coordinates'] != null) {
      final coordinates = ad.additionalData['coordinates'] as List<dynamic>;
      final adLocation = GeoPoint(coordinates[1], coordinates[0]);
      final distance = userLocation!.distanceTo(adLocation);
      locationText += ' • ${_formatDistance(distance)}';
    }

    return locationText;
  }
}
