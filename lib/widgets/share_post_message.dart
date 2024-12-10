import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/news.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product_post.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:happy/classes/promo_codes.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/screens/marketplace/ad_card.dart';
import 'package:happy/screens/marketplace/ad_detail_page.dart';
import 'package:happy/widgets/cards/concours_card.dart';
import 'package:happy/widgets/cards/deals_express_card.dart';
import 'package:happy/widgets/cards/emploi_card.dart';
import 'package:happy/widgets/cards/evenement_card.dart';
import 'package:happy/widgets/cards/happy_deals_card.dart';
import 'package:happy/widgets/cards/news_card.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';
import 'package:happy/widgets/cards/product_cards.dart';
import 'package:provider/provider.dart';

class SharedPostMessage extends StatelessWidget {
  final Message message;
  final bool isMe;

  const SharedPostMessage({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final postData = message.postData as Map<String, dynamic>;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .doc(postData['postId'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Erreur de chargement du post');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Post non trouvé');
        }

        final post = Post.fromDocument(snapshot.data!);
        final postData = snapshot.data!.data() as Map<String, dynamic>;
        final companyId = postData['companyId'] ?? '';

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('companys')
              .doc(companyId)
              .get(),
          builder: (context, companySnapshot) {
            if (companySnapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            String companyName = '';
            String companyLogo = '';
            String companyCover = '';
            String companyCategorie = '';

            if (companySnapshot.hasData && companySnapshot.data!.exists) {
              final companyData =
                  companySnapshot.data!.data() as Map<String, dynamic>;
              companyName = companyData['name'] ?? '';
              companyLogo = companyData['logo'] ?? '';
              companyCover = companyData['cover'] ?? '';
              companyCategorie = companyData['categorie'] ?? '';
            }

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.grey[300] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (postData['comment'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              postData['comment'],
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: 400,
                          child: _buildPostContent(
                            post,
                            context,
                            companyName: companyName,
                            companyLogo: companyLogo,
                            companyCover: companyCover,
                            companyCategorie: companyCategorie,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostContent(
    Post post,
    BuildContext context, {
    required String companyName,
    required String companyLogo,
    required String companyCover,
    required String companyCategorie,
  }) {
    switch (post.runtimeType) {
      case JobOffer:
        return SizedBox(
          child: JobOfferCard(
            post: post as JobOffer,
            companyName: companyName, // Ces informations doivent venir du post
            companyLogo: companyLogo,
          ),
        );

      case Contest:
        return SizedBox(
          child: ConcoursCard(
            contest: post as Contest,
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            companyName: companyName,
            companyLogo: companyLogo,
          ),
        );

      case HappyDeal:
        return SizedBox(
          child: HappyDealsCard(
            companyCategorie: '',
            post: post as HappyDeal,
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            companyName: companyName,
            companyLogo: companyLogo,
            companyCover: companyCover,
          ),
        );

      case ExpressDeal:
        return SizedBox(
          child: DealsExpressCard(
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            post: post as ExpressDeal,
            companyName: companyName,
            companyLogo: companyLogo,
          ),
        );

      case Referral:
        return SizedBox(
          child: ParrainageCard(
            companyName: companyName,
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
            post: post as Referral,
            companyLogo: companyLogo,
          ),
        );

      case Event:
        return SizedBox(
          child: EvenementCard(
            event: post as Event,
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
        );

      case ProductPost:
        return SizedBox(
          child: ProductCards(
            post: post as ProductPost,
            companyName: companyName,
            companyLogo: companyLogo,
          ),
        );

      case PromoCodePost:
        return SizedBox(
          width: 600,
          child: PromoCodeCard(
            post: post as PromoCodePost,
            companyName: companyName,
            companyLogo: companyLogo,
            currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
        );

      case News:
        return SizedBox(
          child: NewsCard(
            news: post as News,
            companyLogo: companyLogo,
            companyName: companyName,
          ),
        );

      case Ad:
        return SizedBox(
          child: AdCard(
            ad: post as Ad,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdDetailPage(ad: post as Ad),
                ),
              );
            },
            onSaveTap: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  final savedAdsProvider =
                      Provider.of<SavedAdsProvider>(context, listen: false);
                  await savedAdsProvider.toggleSaveAd(user.uid, post.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Erreur lors de la sauvegarde: $e')),
                    );
                  }
                }
              }
            },
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type de post non supporté: ${post.runtimeType}'),
              Text('ID du post: ${post.id}'),
            ],
          ),
        );
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
