import 'package:flutter/material.dart';
import 'package:happy/classes/service_promotion.dart';
import 'package:happy/screens/shop/service_promotion_detail_page.dart';
import 'package:intl/intl.dart';

class ServicePromotionCard extends StatelessWidget {
  final ServicePromotion promotion;

  const ServicePromotionCard({
    super.key,
    required this.promotion,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = promotion.isValid();
    final isExpired = promotion.endDate.isBefore(DateTime.now());
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Fonction pour vérifier si une URL est valide
    bool isValidImageUrl(String url) {
      return url.isNotEmpty && 
             (url.startsWith('http://') || url.startsWith('https://'));
    }

    // Widget pour afficher une image par défaut
    Widget buildDefaultImage() {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey,
            size: 32,
          ),
        ),
      );
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServicePromotionDetailPage(promotion: promotion),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image et badge de réduction
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: isValidImageUrl(promotion.photo)
                    ? Image.network(
                        promotion.photo,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('❌ Erreur de chargement d\'image: $error');
                          return buildDefaultImage();
                        },
                      )
                    : buildDefaultImage(),
              ),
              // Overlay pour promotion expirée
            
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isExpired 
                        ? Colors.grey 
                        : isValid 
                            ? Colors.red 
                            : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isExpired
                        ? 'TERMINÉE'
                        : promotion.discountType == 'fixed'
                            ? '-${promotion.discountValue.toStringAsFixed(0)}€'
                            : '-${promotion.discountPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre de la promotion
                Text(
                  promotion.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isExpired ? Colors.grey : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Prix
                Row(
                  children: [
                    Text(
                      '${promotion.newPrice.toStringAsFixed(2)}€',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isExpired ? Colors.grey : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${promotion.oldPrice.toStringAsFixed(2)}€',
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Dates de validité
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today, 
                      size: 16, 
                      color: isExpired ? Colors.red : Colors.grey
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isExpired
                            ? 'Terminée le ${dateFormat.format(promotion.endDate)}'
                            : 'Valable du ${dateFormat.format(promotion.startDate)} au ${dateFormat.format(promotion.endDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired ? Colors.red : Colors.grey[600],
                          fontWeight: isExpired ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 