import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';

class CompanyInfoCard extends StatelessWidget {
  final Company company;
  final VoidCallback? onTap;
  final bool showRating;
  final bool showVerifiedBadge;
  final bool isCompact;

  const CompanyInfoCard({
    super.key,
    required this.company,
    this.onTap,
    this.showRating = true,
    this.showVerifiedBadge = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isCompact ? 40 : 60,
                  height: isCompact ? 40 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(company.logo),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: isCompact ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              company.name,
                              style: TextStyle(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (showVerifiedBadge) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 6 : 8,
                                vertical: isCompact ? 2 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    size: isCompact ? 12 : 14,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Vérifié',
                                    style: TextStyle(
                                      fontSize: isCompact ? 10 : 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (showRating && (company.numberOfReviews ?? 0) > 0) ...[
                        SizedBox(height: isCompact ? 4 : 8),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 4 : 6,
                                vertical: isCompact ? 1 : 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: isCompact ? 14 : 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (company.averageRating ?? 0.0)
                                        .toStringAsFixed(1),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isCompact ? 12 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${company.numberOfReviews ?? 0} avis)',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isCompact ? 12 : 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: isCompact ? 20 : 24,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
