import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';

class AdCard extends StatelessWidget {
  final Ad ad;
  final VoidCallback onTap;

  const AdCard({super.key, required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: AspectRatio(
              aspectRatio:
                  4 / 3, // Ajusté pour correspondre à l'image de l'exemple
              child: ad.photos.isNotEmpty
                  ? Image.network(
                      ad.photos[0],
                      fit: BoxFit.cover,
                    )
                  : Container(color: Colors.grey), // Placeholder
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
    );
  }
}
