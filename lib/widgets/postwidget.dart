import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/comments_page.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/widgets/cards/concours_card.dart';
import 'package:happy/widgets/cards/deals_express_card.dart';
import 'package:happy/widgets/cards/emploi_card.dart';
import 'package:happy/widgets/cards/evenement_card.dart';
import 'package:happy/widgets/cards/happy_deals_card.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostWidget extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onView;
  final String companyName;
  final String companyCategorie;
  final String companyLogo;
  final String companyCover;
  final Map<String, dynamic> companyData;
  final Map<String, dynamic>? sharedByUserData;

  const PostWidget({
    required Key key,
    required this.post,
    required this.currentUserId,
    required this.onView,
    required this.companyName,
    required this.companyCategorie,
    required this.companyLogo,
    required this.companyCover,
    required this.companyData,
    this.sharedByUserData,
  }) : super(key: key);

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.post is SharedPost) _buildSharedPostHeader(),
        _buildPostContent(),
        _buildInteractionBar(),
      ],
    );
  }

  Widget _buildSharedPostHeader() {
    final sharedPost = widget.post as SharedPost;
    final userData = widget.sharedByUserData;

    return ListTile(
      leading: GestureDetector(
        onTap: () => _navigateToUserProfile(sharedPost.sharedBy!),
        child: CircleAvatar(
          backgroundImage: NetworkImage(userData?['profileImageUrl'] ?? ''),
          backgroundColor: Colors.grey, // Fallback color if no image
        ),
      ),
      title: GestureDetector(
        onTap: () => _navigateToUserProfile(sharedPost.sharedBy!),
        child: Text(
          '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''} a partagé',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      subtitle: Text(timeago.format(sharedPost.sharedAt ?? sharedPost.timestamp,
          locale: 'fr')),
    );
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Profile(userId: userId),
      ),
    );
  }

  Widget _buildPostContent() {
    if (widget.post is SharedPost) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('posts')
            .doc((widget.post as SharedPost).originalPostId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Text('Erreur de chargement du post original');
          }
          final originalPost = Post.fromDocument(snapshot.data!);
          return _buildPostTypeContent(originalPost);
        },
      );
    } else {
      return _buildPostTypeContent(widget.post);
    }
  }

  Widget _buildPostTypeContent(Post post) {
    switch (post.runtimeType) {
      case JobOffer:
        return JobOfferCard(
          post: post as JobOffer,
          companyName: widget.companyName,
          companyLogo: widget.companyLogo,
        );
      case Contest:
        return ConcoursCard(
          contest: post as Contest,
          currentUserId: widget.currentUserId,
          companyName: widget.companyName,
          companyLogo: widget.companyLogo,
        );
      case HappyDeal:
        return HappyDealsCard(
          companyCategorie: widget.companyCategorie,
          post: post as HappyDeal,
          currentUserId: widget.currentUserId,
          companyName: widget.companyName,
          companyLogo: widget.companyLogo,
          companyCover: widget.companyCover,
        );
      case ExpressDeal:
        return DealsExpressCard(
          currentUserId: widget.currentUserId,
          post: post as ExpressDeal,
          companyName: widget.companyName,
          companyLogo: widget.companyLogo,
        );
      case Referral:
        return ParrainageCard(
          companyName: widget.companyName,
          currentUserId: widget.currentUserId,
          post: post as Referral,
          companyLogo: widget.companyLogo,
        );
      case Event:
        return EvenementCard(
          event: post as Event,
          currentUserId: widget.currentUserId,
        );
      default:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type de post non supporté: ${post.runtimeType}'),
                Text('ID du post: ${post.id}'),
                Text('Entreprise: ${widget.companyName}'),
                Text('Catégorie: ${widget.companyCategorie}'),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildInteractionBar() {
    return Consumer<UserModel>(
      builder: (context, users, _) {
        final isLiked = users.likedPosts.contains(widget.post.id);
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : null,
                      ),
                      onPressed: () async => await context
                          .read<UserModel>()
                          .handleLike(widget.post),
                    ),
                    Text('${widget.post.likes}'),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: const Icon(Icons.comment_outlined),
                      onPressed: () => _navigateToComments(context),
                    ),
                    const SizedBox(width: 5),
                    Text('${widget.post.commentsCount}')
                  ],
                ),
                IconButton(
                  onPressed: () async => await context
                      .read<UserModel>()
                      .sharePost(widget.post.id, users.userId),
                  icon: const Icon(Icons.share_outlined),
                )
              ],
            ),
            Divider(height: 20, color: Colors.grey[300]),
          ],
        );
      },
    );
  }

  void _navigateToComments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentScreen(
          post: widget.post,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }
}
