import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:happy/config/app_router.dart';

class PromoCodeCard extends StatelessWidget {
  final PromoCodePost post;
  final String currentUserId;

  const PromoCodeCard({
    super.key,
    required this.post,
    required this.currentUserId,
  });

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
    final isExpired = post.expiresAt != null && post.expiresAt!.isBefore(DateTime.now());
    
    return Column(
      children: [
        // Carte Code Promo
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: InkWell(
            onTap: () => Navigator.pushNamed(
              context,
              AppRouter.promoCodeDetails,
              arguments: {
                'post': post,
                'companyName': post.companyName,
                'companyLogo': post.companyLogo,
              },
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
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
                                color: isExpired ? Colors.grey[200] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isExpired ? Colors.grey[400]! : Colors.grey[300]!,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    post.code,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      color: isExpired ? Colors.grey[600] : Colors.black,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: isExpired ? null : () =>
                                        _copyToClipboard(context, post.code),
                                    icon: Icon(
                                      Icons.copy_rounded,
                                      color: isExpired ? Colors.grey[400] : Colors.blue[700],
                                    ),
                                    tooltip: isExpired ? 'Code expiré' : 'Copier le code',
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
                              color: isExpired ? Colors.grey[100] : Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              post.isPercentage
                                  ? '-${post.discountValue.toStringAsFixed(0)}%'
                                  : '-${post.discountValue.toStringAsFixed(2)}€',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isExpired ? Colors.grey[500] : Colors.blue[700],
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
                          color: isExpired ? Colors.grey[500] : Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Badge d'expiration
                if (isExpired)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'EXPIRÉ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
  }
}
