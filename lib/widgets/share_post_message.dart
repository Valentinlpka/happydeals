import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/screens/troc-et-echange/ad_card.dart';
import 'package:happy/screens/troc-et-echange/ad_detail_page.dart';
import 'package:happy/widgets/postwidget.dart';
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

            if (!companySnapshot.hasData || !companySnapshot.data!.exists) {
              return const Text('Entreprise non trouvée');
            }

            final companyData =
                companySnapshot.data!.data() as Map<String, dynamic>;
            final company = CompanyData(
              name: companyData['name'] ?? '',
              category: companyData['categorie'] ?? '',
              logo: companyData['logo'] ?? '',
              cover: companyData['cover'] ?? '',
              rawData: companyData,
            );

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
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
                            company: company,
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
    required CompanyData company,
  }) {
    if (post is Ad) {
      final ad = post as Ad;
      return SizedBox(
        child: AdCard(
          ad: ad,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdDetailPage(ad: ad),
              ),
            );
          },
          onSaveTap: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                final savedAdsProvider =
                    Provider.of<SavedAdsProvider>(context, listen: false);
                await savedAdsProvider.toggleSaveAd(user.uid, ad.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
                  );
                }
              }
            }
          },
        ),
      );
    }

    return PostWidget(
      post: post,
      onView: () {
        // TODO: Implémenter la navigation vers la vue détaillée
      },
      currentProfileUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
      currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
      companyData: company,
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
