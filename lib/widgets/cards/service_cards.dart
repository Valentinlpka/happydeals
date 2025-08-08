import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/classes/service_post.dart';
import 'package:happy/config/app_router.dart';
import 'package:intl/intl.dart';

class ServiceCards extends StatefulWidget {
  final ServicePost post;

  const ServiceCards({
    super.key,
    required this.post,
  });

  @override
  State<ServiceCards> createState() => _ServiceCardsState();
}

class _ServiceCardsState extends State<ServiceCards> {
  late Future<ServiceModel?> serviceFuture;

  @override
  void initState() {
    super.initState();
    if (widget.post.serviceId.isEmpty) {
      debugPrint('ERREUR: serviceId est vide pour le post ${widget.post.id}');
      serviceFuture = Future.value(ServiceModel(
        id: '',
        professionalId: widget.post.professionalId,
        name: widget.post.name,
        description: widget.post.description,
        price: widget.post.price,
        tva: widget.post.tva.toInt(),
        duration: widget.post.duration,
        images: widget.post.images,
        isActive: widget.post.isActive,
        discount: widget.post.discount != null
            ? ServiceDiscount(
                type: widget.post.discount!.type,
                value: double.parse(widget.post.discount!.value.toString()),
                startDate: Timestamp.fromDate(widget.post.discount!.startDate),
                endDate: Timestamp.fromDate(widget.post.discount!.endDate),
                isActive: widget.post.discount!.isActive,
              )
            : null,
        stripeProductId: '',
        stripePriceId: '',
        timestamp: DateTime.now(),
        updatedAt: DateTime.now(),
        companyName: widget.post.companyName,
        companyLogo: widget.post.companyLogo,
        companyAddress: widget.post.companyAddress ?? {},
        companyId: widget.post.companyId, 
      ));
    } else {
      serviceFuture = _getService(widget.post.serviceId);
    }
  }

  Future<ServiceModel?> _getService(String serviceId) async {
    if (serviceId.isEmpty) {
      debugPrint(
          'ERREUR: Tentative de récupération d\'un service avec un ID vide');
      return null;
    }

    try {
      final serviceDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(serviceId)
          .get();

      if (serviceDoc.exists) {
        return ServiceModel.fromMap(serviceDoc.data()!);
      }
      debugPrint('Service not found');
      return null;
    } catch (e) {
      debugPrint('Error fetching service: $e');
      return null;
    }
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '${hours}h';
      }
      return '${hours}h${remainingMinutes.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildPromotionBadge(ServiceModel service) {
    if (!service.hasActivePromotion) return const SizedBox.shrink();

    final discount = service.discount!;
    final discountText = discount.type == 'percentage'
        ? '${discount.value.toStringAsFixed(0)}%'
        : '${discount.value.toStringAsFixed(2)}€';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[700],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_offer_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            '-$discountText',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Fonction utilitaire pour valider l'URL de l'image
  bool _isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final trimmedUrl = url.trim();
    if (trimmedUrl.startsWith('file:///')) return false;
    return trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ServiceModel?>(
      future: serviceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('Service non trouvé'));
        }

        final service = snapshot.data!;

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.all(10),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRouter.serviceDetails,
                    arguments: service.id,
                  );
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'service-${service.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: service.images.isNotEmpty && _isValidImageUrl(service.images[0])
                            ? Stack(
                                children: [
                                  Image.network(
                                    service.images[0],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint('Erreur de chargement de l\'image: $error');
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[100],
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 40,
                                          color: Colors.grey[400],
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[100],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (service.hasActivePromotion)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: _buildPromotionBadge(service),
                                    ),
                                ],
                              )
                            : Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[100],
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 124,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  service.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDuration(service.duration),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            _buildPriceSection(service),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildPriceSection(ServiceModel service) {
    if (service.hasActivePromotion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "${service.finalPrice.toStringAsFixed(2)} €",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[800],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                "${service.price.toStringAsFixed(2)} €",
                style: TextStyle(
                  fontSize: 13,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          if (service.discount?.endDate != null)
            Text(
              'Jusqu\'au ${DateFormat('dd/MM/yyyy').format(service.discount!.endDate!.toDate())}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
        ],
      );
    }

    return Text(
      "${service.price.toStringAsFixed(2)} €",
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
