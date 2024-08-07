import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/comments_page.dart';
import 'package:happy/widgets/cards/concours_card.dart';
import 'package:happy/widgets/cards/deals_express_card.dart';
import 'package:happy/widgets/cards/emploi_card.dart';
import 'package:happy/widgets/cards/evenement_card.dart';
import 'package:happy/widgets/cards/happy_deals_card.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';
import 'package:provider/provider.dart';

class PostWidget extends StatefulWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onView;
  final String companyName;
  final String companyCategorie;
  final String companyLogo;
  final String companyCover;

  const PostWidget({
    required Key key,
    required this.post,
    required this.currentUserId,
    required this.onView,
    required this.companyName,
    required this.companyCategorie,
    required this.companyLogo,
    required this.companyCover,
  }) : super(key: key);

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  @override
  Widget build(BuildContext context) {
    Widget content;
    if (widget.post is JobOffer) {
      content = JobOfferCard(
        post: widget.post as JobOffer,
        companyName: widget.companyName,
        companyLogo: widget.companyLogo,
      );
    } else if (widget.post is Contest) {
      content = ConcoursCard(
        contest: widget.post as Contest,
        currentUserId: widget.currentUserId,
        companyName: widget.companyName,
        companyLogo: widget.companyLogo,
      );
    } else if (widget.post is HappyDeal) {
      content = HappyDealsCard(
        companyCategorie: widget.companyCategorie,
        post: widget.post as HappyDeal,
        currentUserId: widget.currentUserId,
        companyName: widget.companyName,
        companyLogo: widget.companyLogo,
        companyCover: widget.companyCover,
      );
    } else if (widget.post is ExpressDeal) {
      content = DealsExpressCard(
        currentUserId: widget.currentUserId,
        post: widget.post as ExpressDeal,
        companyName: widget.companyName,
        companyLogo: widget.companyLogo,
      );
    } else if (widget.post is Referral) {
      content = ParrainageCard(
        companyName: widget.companyName,
        currentUserId: widget.currentUserId,
        post: widget.post as Referral,
        companyLogo: widget.companyLogo,
      );
    } else if (widget.post is Event) {
      content = EvenementCard(
        event: widget.post as Event,
        currentUserId: widget.currentUserId,
      );
    } else {
      content = Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unsupported post type: ${widget.post.runtimeType}'),
              Text('Post ID: ${widget.post.id}'),
              Text('Company: ${widget.companyName}'),
              Text('Category: ${widget.companyCategorie}'),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        Column(
          children: [
            Consumer<UserModel>(
              builder: (context, users, _) {
                final isLiked = users.likedPosts.contains(widget.post.id);
                return Row(
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommentScreen(
                                  post: widget.post,
                                  currentUserId: widget.currentUserId,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 5),
                        Text('${widget.post.commentsCount}')
                      ],
                    ),
                    const Icon(Icons.share_outlined)
                  ],
                );
              },
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
