import 'package:flutter/material.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/config/app_router.dart';

class JobOfferCard extends StatelessWidget {
  final JobOffer post;
  final String companyName;
  final String companyLogo;

  const JobOfferCard({
    super.key,
    required this.post,
    required this.companyName,
    required this.companyLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Carte de l'offre d'emploi
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRouter.jobDetails,
                arguments: {
                  'post': post,
                  'individualName': companyName,
                  'individualPhoto': companyLogo,
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre et type de contrat
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Badges en ligne séparée
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (post.contractType != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            post.contractType!,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (post.industrySector.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 12,
                                color: Colors.purple[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                post.industrySector,
                                style: TextStyle(
                                  color: Colors.purple[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Localisation et horaires
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 4),
                            Text(
                              post.city,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (post.workingHours != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 16, color: Colors.grey[700]),
                              const SizedBox(width: 4),
                              Text(
                                post.workingHours!,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Salaire si disponible
                  if (post.salary != '')
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            post.salary!,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Mots-clés
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: post.keywords.map((keyword) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo[50],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          keyword,
                          style: TextStyle(
                            color: Colors.indigo[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
