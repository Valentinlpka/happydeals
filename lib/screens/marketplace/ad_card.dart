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

        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 380, // Hauteur fixe pour la carte
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Image - Hauteur fixe
                      SizedBox(
                        height: 180, // Hauteur fixe pour l'image
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ad.photos.isNotEmpty
                                  ? Image.network(
                                      ad.photos[0],
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                            ),
                            // Badge Type d'échange
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[700],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  ad.additionalData['exchangeType'] ??
                                      'Échange',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            // Bouton Sauvegarder
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                onPressed: onSaveTap,
                                icon: Icon(
                                  isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color:
                                      isSaved ? Colors.blue[700] : Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black26,
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Section Informations - Reste de l'espace disponible
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ad.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Catégorie et Localisation
                              Row(
                                children: [
                                  Icon(Icons.category_outlined,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      ad.additionalData['category'] ??
                                          'Non catégorisé',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.location_on_outlined,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      ad.additionalData['location'] ??
                                          'Non spécifié',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Informations spécifiques selon le type
                              if (ad.additionalData['exchangeType'] ==
                                  'Article') ...[
                                _buildInfoRow(
                                  'État',
                                  ad.additionalData['condition'] ??
                                      'Non spécifié',
                                ),
                                if (ad.additionalData['brand']?.isNotEmpty ??
                                    false)
                                  _buildInfoRow(
                                    'Marque',
                                    ad.additionalData['brand'],
                                  ),
                              ] else if (ad.additionalData['exchangeType'] ==
                                  'Temps et Compétences') ...[
                                _buildInfoRow(
                                  'Disponibilité',
                                  ad.additionalData['availability'] ??
                                      'Non spécifié',
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Souhaits d'échange
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.swap_horiz,
                                        size: 16, color: Colors.blue[700]),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        ad.additionalData['wishInReturn'] ??
                                            'Ouvert aux propositions',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
