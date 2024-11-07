import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:provider/provider.dart';

class AdCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap;
  final VoidCallback onSaveTap;

  const AdCard({
    super.key,
    required this.ad,
    required this.onTap,
    required this.onSaveTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SavedAdsProvider>(
      builder: (context, savedAdsProvider, _) {
        final isSaved = savedAdsProvider.isAdSaved(ad.id);

        return InkWell(
          onTap: onTap,
          child: Card(
            elevation: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: ad.photos.isNotEmpty
                            ? Image.network(ad.photos[0], fit: BoxFit.cover)
                            : Container(color: Colors.grey),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ),
                    if (ad.status == 'sold')
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.green,
                          child: const Text(
                            'VENDU',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () {
                          onSaveTap();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isSaved
                                    ? 'Annonce retirée des favoris'
                                    : 'Annonce ajoutée aux favoris',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.blue[600],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: isSaved ? Colors.blue[600] : Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ad.price.toStringAsFixed(2)} €',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ad.additionalData['location'] ?? '',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ad.formattedDate,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
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
}
