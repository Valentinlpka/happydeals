import 'package:flutter/material.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/config/app_router.dart';
import 'package:intl/intl.dart';

class ParrainageCard extends StatelessWidget {
  final Referral post;
  final String currentUserId;
  final String companyLogo;
  final String companyName;

  const ParrainageCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.companyLogo,
    required this.companyName,
  });

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('d MMMM yyyy', 'fr_FR').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Carte principale
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRouter.referralDetails,
                arguments: {
                  'referral': post,
                  'currentUserId': currentUserId,
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Date de fin
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Jusqu'au ${_formatDateTime(post.dateFinal)}",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    post.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Avantages
                  Row(
                    children: [
                      Expanded(
                        child: _buildBenefitCard(
                          "Parrain",
                          post.sponsorBenefit,
                          Colors.blue[700]!,
                          Colors.blue[50]!,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBenefitCard(
                          "Filleul",
                          post.refereeBenefit,
                          Colors.green[700]!,
                          Colors.green[50]!,
                        ),
                      ),
                    ],
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

  Widget _buildBenefitCard(
      String title, String benefit, Color textColor, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor.withAlpha(26 * 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            benefit,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
