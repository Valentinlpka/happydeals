import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/like_provider.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/comments_page.dart';
import 'package:happy/widgets/concours_card.dart';
import 'package:happy/widgets/deals_express_card.dart';
import 'package:happy/widgets/emploi_card.dart';
import 'package:happy/widgets/evenement_card.dart';
import 'package:happy/widgets/happy_deals_card.dart';
import 'package:provider/provider.dart';

class PostWidget extends StatelessWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onView;
  final String companyName;
  final String companyCategorie;
  final String companyLogo;

  const PostWidget({
    required Key key,
    required this.post,
    required this.currentUserId,
    required this.onView,
    required this.companyName,
    required this.companyCategorie,
    required this.companyLogo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final likeProvider = Provider.of<Users>(context, listen: false);
    Widget content;
    if (post is JobOffer) {
      content = JobOfferCard(
        post: post as JobOffer,
        companyName: companyName,
        companyLogo: companyLogo,
      );
    } else if (post is Contest) {
      content = const ConcoursCard();
    } else if (post is HappyDeal) {
      content = HappyDealsCard(
        companyCategorie: companyCategorie,
        post: post as HappyDeal,
        currentUserId: currentUserId,
        companyName: companyName,
        companyLogo: companyLogo,
      );
    } else if (post is ExpressDeal) {
      content = DealsExpressCard(
        currentUserId: currentUserId,
        post: post as ExpressDeal,
        companyName: companyName,
        companyLogo: companyLogo,
      );
    } else if (post is Referral) {
      content = const ConcoursCard();
    } else if (post is Event) {
      content = EvenementCard(
        event: post as Event,
        currentUserId: currentUserId,
      );
    } else {
      content = const Text('Unsupported post type');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        post.likedBy.contains(currentUserId)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.likedBy.contains(currentUserId)
                            ? Colors.red
                            : null,
                      ),
                      onPressed: () => likeProvider.handleLike(post),
                    ),
                    Text('${post.likes}'),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: const Icon(Icons.comment_outlined),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CommentScreen(
                              post: post,
                              currentUserId: currentUserId,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 5),
                    Text('${post.commentsCount}')
                  ],
                ),
                const Icon(Icons.share_outlined)
              ],
            ),
            Divider(
              height: 20,
              color: Colors.grey[300],
            )
          ],
        ),
      ],
    );
  }
}
