import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/promo_code_detail.dart';
import 'package:intl/intl.dart';

class PromoCodeCard extends StatelessWidget {
  final PromoCodePost post;
  final String companyName;
  final String companyLogo;
  final String currentUserId;

  const PromoCodeCard({
    super.key,
    required this.post,
    required this.companyName,
    required this.companyLogo,
    required this.currentUserId,
  });

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('d MMMM yyyy', 'fr_FR').format(dateTime);
  }

  Future<void> _copyToClipboard(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Code "$code" copié avec succès !'),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // En-tête avec logo et informations
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailsEntreprise(
                  entrepriseId: post.companyId,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF3476B2),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(companyLogo),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.confirmation_number,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Code Promo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateTime(post.timestamp),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Carte Code Promo
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PromoCodeDetails(
                  post: post,
                  companyName: companyName,
                  companyLogo: companyLogo,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                post.code,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _copyToClipboard(context, post.code),
                                icon: Icon(Icons.copy_rounded,
                                    color: Colors.blue[700]),
                                tooltip: 'Copier le code',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          post.isPercentage
                              ? '-${post.discountValue.toStringAsFixed(0)}%'
                              : '-${post.discountValue.toStringAsFixed(2)}€',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    post.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
