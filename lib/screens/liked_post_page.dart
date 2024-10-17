import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';

class LikedPostsPage extends StatefulWidget {
  const LikedPostsPage({super.key});

  @override
  _LikedPostsPageState createState() => _LikedPostsPageState();
}

class _LikedPostsPageState extends State<LikedPostsPage> {
  final String currentUserId =
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  final PagingController<DocumentSnapshot?, Map<String, dynamic>>
      _pagingController = PagingController(firstPageKey: null);
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(DocumentSnapshot? pageKey) async {
    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      final likedPostIds = userModel.likedPosts;

      Query query = FirebaseFirestore.instance
          .collection('posts')
          .where(FieldPath.documentId, whereIn: likedPostIds)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      if (pageKey != null) {
        query = query.startAfterDocument(pageKey);
      }

      final querySnapshot = await query.get();
      final List<Map<String, dynamic>> newPosts = [];

      for (var doc in querySnapshot.docs) {
        try {
          final post = _createPostFromDocument(doc);
          if (post != null) {
            final companyData = await _getCompanyData(post.companyId);
            newPosts.add({
              'post': post,
              'company': companyData,
            });
          }
        } catch (e) {
          // Skip this post and continue with the next one
        }
      }

      final isLastPage = newPosts.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newPosts);
      } else {
        final lastDocument = querySnapshot.docs.last;
        _pagingController.appendPage(newPosts, lastDocument);
      }
    } catch (error) {
      _pagingController.error = error;
    }
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
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts likés'),
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.sync(() => _pagingController.refresh()),
        child: PagedListView<DocumentSnapshot?, Map<String, dynamic>>(
          pagingController: _pagingController,
          builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
            noItemsFoundIndicatorBuilder: (_) => const Center(
              child: Text(
                'Vous n\'avez pas encore liké de posts',
                textAlign: TextAlign.center,
              ),
            ),
            itemBuilder: (context, postData, index) {
              final post = postData['post'] as Post;
              final companyData = postData['company'] as Map<String, dynamic>;
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
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getCompanyData(String companyId) async {
    DocumentSnapshot companyDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();

    return companyDoc.data() as Map<String, dynamic>;
  }
}
