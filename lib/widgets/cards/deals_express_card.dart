import 'package:flutter/material.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/config/app_router.dart';
import 'package:intl/intl.dart';

class DealsExpressCard extends StatelessWidget {
  final ExpressDeal post;
  final String currentUserId;
  final String companyName;
  final String companyLogo;
  final String? companyCity;
  final String? distance;
  final bool isHorizontal;

  const DealsExpressCard({
    super.key,
    required this.post,
    required this.companyName,
    required this.companyLogo,
    required this.currentUserId,
    this.companyCity,
    this.distance,
    this.isHorizontal = false,
  });

  String _formatDateTime(DateTime dateTime) {
    final DateTime now = DateTime.now();
    final DateFormat timeFormat = DateFormat('HH:mm');
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy');

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'aujourd\'hui à ${timeFormat.format(dateTime)}';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day + 1) {
      return 'demain à ${timeFormat.format(dateTime)}';
    } else {
      return 'le ${dateFormat.format(dateTime)} à ${timeFormat.format(dateTime)}';
    }
  }

  String _getTimeRemaining(DateTime pickupTime) {
    final now = DateTime.now();
    final difference = pickupTime.difference(now);

    if (difference.isNegative) return 'Expiré';

    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h${minutes > 0 ? ' ${minutes}min' : ''} restant';
    } else if (minutes > 0) {
      return '${minutes}min restant';
    } else {
      return 'Moins d\'1min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = post.availableBaskets > 0;
    final timeRemaining = _getTimeRemaining(post.pickupTimes[0]);

    if (isHorizontal) {
      return Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: InkWell(
            onTap: isActive
                ? () {
                    Navigator.pushNamed(
                      context,
                      AppRouter.dealExpressDetails,
                      arguments: {
                        'post': post,
                      },
                    );
                  }
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        post.imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/UP.png',
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    if (!isActive)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(20),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Indisponible',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Contenu
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête avec logo et nom

                      const SizedBox(height: 8),

                      // Titre
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Prix et disponibilité
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${post.price.toStringAsFixed(2)} €",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green[50]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isActive
                                    ? Colors.green[200]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Text(
                              isActive
                                  ? '${post.availableBaskets} restants'
                                  : 'Épuisé',
                              style: TextStyle(
                                color: isActive
                                    ? Colors.green[700]
                                    : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Version verticale existante
    return Column(
      children: [
        // Carte du Deal Express avec image
        Stack(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: isActive
                    ? () {
                        Navigator.pushNamed(
                          context,
                          AppRouter.dealExpressDetails,
                          arguments: {
                            'post': post,
                          },
                        );
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image principale
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 160, // Hauteur maximale fixée
                        ),
                        child: post.imageUrl.isNotEmpty
                            ? Image.network(
                                post.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/images/UP.png',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  );
                                },
                              )
                            : Image.asset(
                                'assets/images/UP.png',
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Badge paniers disponibles
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.green[50]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.green[200]!
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_basket_rounded,
                                      size: 16,
                                      color: isActive
                                          ? Colors.green[700]
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isActive
                                          ? '${post.availableBaskets} panier${post.availableBaskets > 1 ? 's' : ''}'
                                          : 'Indisponible',
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.green[700]
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Timer
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.orange[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 16,
                                      color: Colors.orange[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      timeRemaining,
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "À récupérer ${_formatDateTime(post.pickupTimes[0])}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '-50%',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    "${post.price.toStringAsFixed(2)} €",
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${(post.price * 2).toStringAsFixed(2)} €",
                                    style: TextStyle(
                                      fontSize: 16,
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isActive)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(62),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(90),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 8,
                              offset: const Offset(4, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Victime de son succès',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
