import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/classes/service_post.dart';
import 'package:happy/config/app_router.dart';

class ServiceCards extends StatefulWidget {
  final ServicePost post;
  final String companyName;
  final String companyLogo;

  const ServiceCards({
    super.key,
    required this.post,
    required this.companyName,
    required this.companyLogo,
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
        discount: widget.post.discount?.toMap(),
        stripeProductId: '',
        stripePriceId: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
          .collection('services')
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
                        child: service.images.isNotEmpty
                            ? Image.network(
                                service.images[0],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
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
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 120,
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
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
                                const SizedBox(height: 8),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                if (service.hasActivePromotion) ...[
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
                                      fontSize: 14,
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ] else
                                  Text(
                                    "${service.price.toStringAsFixed(2)} €",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
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
}
