import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/card_promo_code.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/news.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product_post.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/comments_page.dart';
import 'package:happy/screens/marketplace/ad_card.dart';
import 'package:happy/screens/marketplace/ad_detail_page.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/widgets/cards/concours_card.dart';
import 'package:happy/widgets/cards/deals_express_card.dart';
import 'package:happy/widgets/cards/emploi_card.dart';
import 'package:happy/widgets/cards/evenement_card.dart';
import 'package:happy/widgets/cards/happy_deals_card.dart';
import 'package:happy/widgets/cards/news_card.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';
import 'package:happy/widgets/cards/product_cards.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:visibility_detector/visibility_detector.dart';

class PostWidget extends StatefulWidget {
  final Ad? ad;
  final Post post;
  final String currentUserId;
  final String currentProfileUserId; // Ajoutez cette nouvelle propriété

  final VoidCallback onView;
  final String companyName;
  final String companyCategorie;
  final String companyLogo;
  final String companyCover;
  final Map<String, dynamic> companyData;
  final Map<String, dynamic>? sharedByUserData;

  const PostWidget({
    this.ad,
    required Key key,
    required this.post,
    required this.currentUserId,
    required this.currentProfileUserId,
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

class _PostWidgetState extends State<PostWidget>
    with AutomaticKeepAliveClientMixin {
  BuildContext? _scaffoldContext;

  final GlobalKey _postKey = GlobalKey();
  bool _isPostVisible = false;
  StreamSubscription? _visibilitySubscription;
  bool _hasIncrementedView = false; // Pour éviter les incrémentations multiples

  @override
  bool get wantKeepAlive => _isPostVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldContext = context;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted) return;

    final RenderBox? renderBox =
        _postKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final bool isVisible = renderBox.hasSize && renderBox.size.height > 0;
    if (isVisible != _isPostVisible) {
      setState(() {
        _isPostVisible = isVisible;
      });
      updateKeepAlive();

      if (isVisible && !_hasIncrementedView) {
        _incrementPostViews();
        _hasIncrementedView = true;
      }
    }
  }

  Future<void> _incrementPostViews() async {
    if (!mounted) return;

    try {
      await widget.post.incrementViews();
      if (kDebugMode) {
        print('Vues incrémentées pour le post: ${widget.post.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de l\'incrémentation des vues: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return VisibilityDetector(
      key: Key(widget.post.id),
      onVisibilityChanged: (VisibilityInfo info) {
        if (info.visibleFraction > 0.5 && !_hasIncrementedView) {
          _incrementPostViews();
          _hasIncrementedView = true;
        }
      },
      child: RepaintBoundary(
        key: _postKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.post is SharedPost) _buildSharedPostHeader(),
            _buildPostContent(),
            _buildInteractionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedPostHeader() {
    final sharedPost = widget.post as SharedPost;
    final userData = widget.sharedByUserData;
    final currentUserId = Provider.of<UserModel>(context, listen: false).userId;

    // Déterminez le texte à afficher en fonction du contenu partagé
    final sharedText = sharedPost.comment == "a publié une annonce"
        ? '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''} a publié une annonce'
        : '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''} a partagé';

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: GestureDetector(
            onTap: () => _navigateToUserProfile(sharedPost.sharedBy),
            child: CircleAvatar(
              backgroundImage:
                  NetworkImage(userData?['userProfilePicture'] ?? ''),
              backgroundColor: Colors.grey, // Couleur par défaut si pas d'image
              onBackgroundImageError: (exception, stackTrace) {
                print('Erreur de chargement image: $exception');
                print('userData: $userData');
              },
            ),
          ),
          title: GestureDetector(
            onTap: () => _navigateToUserProfile(sharedPost.sharedBy),
            child: Text(
              sharedText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          subtitle: Text(timeago.format(sharedPost.sharedAt, locale: 'fr')),
          trailing: sharedPost.sharedBy == currentUserId
              ? IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptionsBottomSheet(context, sharedPost),
                )
              : null,
        ),
        // Affichez le commentaire uniquement si ce n'est pas "a publié une annonce"
        if (sharedPost.comment != "a publié une annonce" &&
            sharedPost.comment != null &&
            sharedPost.comment!.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              sharedPost.comment!,
              style: const TextStyle(fontStyle: FontStyle.normal),
            ),
          ),
      ],
    );
  }

  void _showOptionsBottomSheet(BuildContext context, SharedPost post) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Wrap(
          children: <Widget>[
            // Afficher l'option de modification seulement si le commentaire n'est pas "a publié une annonce"
            if (post.comment != "a publié une annonce")
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Modifier le commentaire'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditCommentDialog(context, post);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Supprimer le partage'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmationDialog(context, post);
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditCommentDialog(BuildContext context, SharedPost post) {
    final TextEditingController controller =
        TextEditingController(text: post.comment);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Modifier le commentaire'),
          content: TextField(
            controller: controller,
            decoration:
                const InputDecoration(hintText: "Entrez votre commentaire"),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Enregistrer'),
              onPressed: () {
                Navigator.of(context).pop();
                _updatePostComment(post, controller.text);
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, SharedPost post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer le partage'),
          content:
              const Text('Êtes-vous sûr de vouloir supprimer ce partage ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Supprimer'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSharedPost(post);
              },
            ),
          ],
        );
      },
    );
  }

  void _updatePostComment(SharedPost post, String newComment) {
    Provider.of<UserModel>(context, listen: false)
        .updateSharedPostComment(post.id, newComment)
        .then((_) {
      _showSnackBar('Commentaire mis à jour avec succès');
    }).catchError((error) {
      _showSnackBar('Erreur lors de la mise à jour du commentaire');
    });
  }

  void _deleteSharedPost(SharedPost post) {
    Provider.of<UserModel>(context, listen: false)
        .deleteSharedPost(post.id)
        .then((_) {
      _showSnackBar('Partage supprimé avec succès');
    }).catchError((error) {
      _showSnackBar('Erreur lors de la suppression du partage');
    });
  }

  void _navigateToUserProfile(String userId) {
    if (userId != widget.currentProfileUserId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Profile(userId: userId),
        ),
      );
    }
  }

  Widget _buildPostContent() {
    if (widget.post is SharedPost) {
      final sharedPost = widget.post as SharedPost;

      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection(sharedPost.comment == "a publié une annonce"
                ? 'ads' // Charge depuis la collection 'ads' pour les annonces
                : 'posts') // Sinon, charge depuis la collection 'posts'
            .doc(sharedPost.originalPostId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Text('Erreur de chargement du post original');
          }

          // Vérifie si le post original est une annonce
          if (sharedPost.comment == "a publié une annonce") {
            return FutureBuilder<Ad>(
              future:
                  Ad.fromFirestore(snapshot.data!), // Obtention de l'objet Ad
              builder: (context, adSnapshot) {
                if (adSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (adSnapshot.hasError || !adSnapshot.hasData) {
                  return const Text('Erreur de chargement de l\'annonce');
                }

                final ad = adSnapshot.data!;
                return SizedBox(
                  width: 250,
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
                      onSaveTap: () => _toggleSaveAd(ad)),
                );
              },
            );
          } else {
            // Sinon, traiter comme un autre type de post
            final originalPost = Post.fromDocument(snapshot.data!);
            return _buildPostTypeContent(originalPost);
          }
        },
      );
    } else {
      return _buildPostTypeContent(widget.post);
    }
  }

  Future<void> _toggleSaveAd(Ad ad) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Vous devez être connecté pour sauvegarder une annonce'),
        ),
      );
      return;
    }

    try {
      final savedAdsProvider =
          Provider.of<SavedAdsProvider>(context, listen: false);
      await savedAdsProvider.toggleSaveAd(user.uid, ad.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
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
          post: post as HappyDeal,
          companyName: widget.companyName,
          companyCover: widget.companyCover,
          companyCategorie: widget.companyCategorie,
          companyLogo: widget.companyLogo,
          currentUserId: widget.currentUserId,
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
          companyName: widget.companyName,
          companyLogo: widget.companyLogo,
          event: post as Event,
          currentUserId: widget.currentUserId,
        );
      case ProductPost:
        return ProductCards(
          post: post as ProductPost,
          companyName: widget.companyName,
          companyLogo: widget.companyLogo,
        );
      case PromoCodePost:
        return PromoCodeCard(
          post: post as PromoCodePost,
          companyName: widget.companyName,
          companyLogo: widget.companyLogo,
          currentUserId: widget.currentUserId,
        );
      case News:
        return NewsCard(
          news: post as News,
          companyLogo: widget.companyLogo,
          companyName: widget.companyName,
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final postData = snapshot.data!.data() as Map<String, dynamic>;
        final commentsCount = postData['commentsCount'] ?? 0;
        final likes = postData['likes'] ?? 0;
        final views = postData['views'] ?? 0;
        final shares = postData['sharesCount'] ?? 0;
        final likedBy = List<String>.from(postData['likedBy'] ?? []);

        return Consumer<UserModel>(
          builder: (context, userModel, _) {
            final isLiked = likedBy.contains(widget.currentUserId);
            final isCurrentUser = widget.post is SharedPost &&
                (widget.post as SharedPost).sharedBy == widget.currentUserId;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '$views vues',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
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
                          onPressed: () async {
                            try {
                              await Provider.of<UserModel>(context,
                                      listen: false)
                                  .handleLike(widget.post);
                            } catch (e) {
                              if (kDebugMode) {
                                print('Erreur lors du like: $e');
                              }
                            }
                          },
                        ),
                        Text('$likes'),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.comment_outlined),
                          onPressed: () => _navigateToComments(context),
                        ),
                        Text('$commentsCount'),
                        const SizedBox(width: 20),
                        if (!isCurrentUser) ...[
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () =>
                                _showShareConfirmation(context, userModel),
                          ),
                          Text('$shares'),
                        ],
                      ],
                    ),
                  ],
                ),
                Divider(height: 20, color: Colors.grey[300]),
              ],
            );
          },
        );
      },
    );
  }

  void _showShareConfirmation(BuildContext context, UserModel users) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const ListTile(
                title: Text(
                  "Partager",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Partager sur mon profil'),
                onTap: () {
                  Navigator.pop(context);
                  // Stockons le BuildContext actuel
                  final scaffoldContext = context;
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return ShareConfirmationDialog(
                        post: widget.post,
                        onConfirm: (String comment) async {
                          try {
                            // Fermer d'abord le dialogue
                            Navigator.of(dialogContext).pop();

                            await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(widget.post.id)
                                .update({
                              'sharesCount': FieldValue.increment(1),
                            });

                            await users.sharePost(
                              widget.post.id,
                              users.userId,
                              comment: comment,
                            );

                            // Utiliser le contexte stocké
                            if (scaffoldContext.mounted) {
                              ScaffoldMessenger.of(scaffoldContext)
                                  .showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Publication partagée avec succès!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            // Utiliser le contexte stocké
                            if (scaffoldContext.mounted) {
                              ScaffoldMessenger.of(scaffoldContext)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text('Erreur lors du partage: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.message_outlined),
                title: const Text('Envoyer en message'),
                onTap: () {
                  Navigator.pop(context); // Ferme le bottom sheet
                  // Ouvre la liste des conversations pour partager
                  _showConversationsList(context, users);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showConversationsList(BuildContext context, UserModel users) {
    final conversationService =
        Provider.of<ConversationService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Envoyer à...",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<String>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(users.userId)
                        .snapshots()
                        .map((doc) => List<String>.from(
                            doc.data()?['followedUsers'] ?? [])),
                    builder: (context, followedSnapshot) {
                      if (!followedSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final followedUsers = followedSnapshot.data!;

                      return FutureBuilder<List<DocumentSnapshot>>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: followedUsers)
                            .get()
                            .then((query) => query.docs),
                        builder: (context, usersSnapshot) {
                          if (!usersSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final usersList = usersSnapshot.data!;

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: usersList.length,
                            itemBuilder: (context, index) {
                              final userData = usersList[index].data()
                                  as Map<String, dynamic>;
                              final userId = usersList[index].id;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: userData['image_profile'] !=
                                          null
                                      ? NetworkImage(userData['image_profile'])
                                      : null,
                                  child: userData['image_profile'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                    '${userData['firstName']} ${userData['lastName']}'),
                                onTap: () async {
                                  try {
                                    // Incrémenter le compteur de partages
                                    await FirebaseFirestore.instance
                                        .collection('posts')
                                        .doc(widget.post.id)
                                        .update({
                                      'sharesCount': FieldValue.increment(1),
                                    });

                                    await conversationService
                                        .sharePostInConversation(
                                      senderId: users.userId,
                                      receiverId: userId,
                                      post: widget.post,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    _showSnackBar('Post partagé avec succès');
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    _showSnackBar('Erreur lors du partage: $e');
                                  }
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message) {
    if (_scaffoldContext != null) {
      ScaffoldMessenger.of(_scaffoldContext!).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    _scaffoldContext = null;
    _visibilitySubscription?.cancel();

    super.dispose();
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

  void _navigateToCompanyDetail(BuildContext context) {
    try {
      final post = widget.post;
      final entityType = post.entityType;

      if (entityType == 'association') {
        Navigator.pushNamed(
          context,
          '/association-detail',
          arguments: post.companyId,
        );
      } else {
        Navigator.pushNamed(
          context,
          '/company-detail',
          arguments: post.companyId,
        );
      }
    } catch (e) {
      print('Erreur de navigation: $e');
      // Optionnel : afficher un message à l'utilisateur
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Impossible d'accéder au détail pour le moment")),
      );
    }
  }
}
