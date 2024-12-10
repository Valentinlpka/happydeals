import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product_post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class LikedPostsPage extends StatelessWidget {
  const LikedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModel>(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

    // Vérifier si l'utilisateur a des posts likés
    if (userModel.likedPosts.isEmpty) {
      return const Scaffold(
        appBar: CustomAppBar(title: 'Posts likés', align: Alignment.center),
        body: Center(
          child: Text(
            'Vous n\'avez pas encore liké de posts',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Posts likés', align: Alignment.center),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where(FieldPath.documentId, whereIn: userModel.likedPosts)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Les posts que vous avez likés ne sont plus disponibles',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final post = _createPostFromDocument(doc);
              if (post == null) return const SizedBox.shrink();

              return FutureBuilder<Map<String, dynamic>>(
                future: _getCompanyData(post.companyId),
                builder: (context, companySnapshot) {
                  if (companySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SizedBox(height: 200); // Placeholder height
                  }

                  if (!companySnapshot.hasData || companySnapshot.hasError) {
                    return const SizedBox.shrink();
                  }

                  final companyData = companySnapshot.data!;

                  return Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: PostWidget(
                      key: ValueKey(post.id),
                      post: post,
                      companyCover: companyData['cover'],
                      companyCategorie: companyData['categorie'] ?? '',
                      companyName: companyData['name'] ?? '',
                      companyLogo: companyData['logo'] ?? '',
                      currentUserId: currentUserId,
                      currentProfileUserId: currentUserId,
                      companyData: companyData,
                      onView: () {
                        // Logique d'affichage du détail du post
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Post? _createPostFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String type = data['type'] ?? 'unknown';

    try {
      switch (type) {
        case 'job_offer':
          return JobOffer.fromDocument(doc);
        case 'contest':
          return Contest.fromDocument(doc);
        case 'happy_deal':
          return HappyDeal.fromDocument(doc);
        case 'express_deal':
          return ExpressDeal.fromDocument(doc);
        case 'referral':
          return Referral.fromDocument(doc);
        case 'event':
          return Event.fromDocument(doc);
        case 'product':
          return ProductPost.fromDocument(doc);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _getCompanyData(String companyId) async {
    try {
      DocumentSnapshot companyDoc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(companyId)
          .get();

      if (!companyDoc.exists) {
        return {};
      }

      return companyDoc.data() as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }
}
