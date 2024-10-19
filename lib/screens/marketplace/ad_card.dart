import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';

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
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ad.photos.isNotEmpty
                          ? Image.network(ad.photos[0], fit: BoxFit.cover)
                          : Container(color: Colors.grey),
                    ),
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(
                            0.3), // Ajout d'une opacité sur l'image
                      ),
                    ),
                  ],
                ),
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
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
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
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: onSaveTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white, // Fond transparent
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  ad.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: ad.isSaved ? Colors.blue : Colors.black,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
