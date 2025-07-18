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

class SharedPostMessage extends StatefulWidget {
  final Message message;
  final bool isMe;

  const SharedPostMessage({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<SharedPostMessage> createState() => _SharedPostMessageState();
}

class _SharedPostMessageState extends State<SharedPostMessage>
    with AutomaticKeepAliveClientMixin {
  static final Map<String, Post> _postCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    final messagePostData = widget.message.postData as Map<String, dynamic>;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .doc(messagePostData['postId'])
          .get(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Erreur de chargement du post');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Post non trouvé');
        }

        final postData = snapshot.data!.data() as Map<String, dynamic>;
        final post = _postCache[messagePostData['postId']] ??
            Post.fromDocument(snapshot.data!);
        _postCache[messagePostData['postId']] = post;

        final companyId = postData['companyId'] ?? '';

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('companys')
              .doc(companyId)
              .get(),
          builder: (context, companySnapshot) {
            if (companySnapshot.hasError) {
              return const Text(
                  'Erreur de chargement des données de l\'entreprise');
            }

            if (companySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!companySnapshot.hasData || !companySnapshot.data!.exists) {
              return const Text('Données de l\'entreprise non trouvées');
            }

            return Container(
              margin: EdgeInsets.only(
                left: widget.isMe ? 50.0 : 8.0,
                right: widget.isMe ? 8.0 : 50.0,
                top: 8.0,
                bottom: 8.0,
              ),
              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isMe ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.message.postData != null &&
                            widget.message.postData!['comment'] != null &&
                            widget.message.postData!['comment']
                                .toString()
                                .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              widget.message.postData!['comment'].toString(),
                              style: TextStyle(
                                color: widget.isMe
                                    ? Colors.black87
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildPostContent(
                            post,
                            context,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatMessageTime(widget.message.timestamp),
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
    BuildContext context,
  ) {
    if (post is Ad) {
      final ad = post as Ad;
      return SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(),
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
                      SnackBar(
                          content: Text('Erreur lors de la sauvegarde: $e')),
                    );
                  }
                }
              }
            },
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(),
        child: PostWidget(
          post: post,
          onView: () {},
          currentProfileUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
          currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
