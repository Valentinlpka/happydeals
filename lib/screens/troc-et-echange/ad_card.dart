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
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    child: SizedBox(
                      width: 120,
                      child: Hero(
                        tag: 'ad_image_${ad.id}',
                        child: Image.network(
                          ad.photos.first,
                          fit: BoxFit.cover,
                          height: double.infinity,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: Colors.blue[700],
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.grey[400],
                                size: 32,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  ad.additionalData['exchangeType'] ??
                                      'Échange',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onSaveTap,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      size: 20,
                                      color: isSaved
                                          ? Colors.blue[700]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  ad.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _getLocationText(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.swap_horiz,
                                        size: 14,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          ad.additionalData['wishInReturn'] ??
                                              'Ouvert aux propositions',
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
                  ),
                ],
              ),
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
