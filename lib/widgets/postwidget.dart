// ignore_for_file: type_literal_in_constant_pattern

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
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
import 'package:happy/classes/service_post.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/screens/troc-et-echange/ad_card.dart';
import 'package:happy/screens/troc-et-echange/ad_detail_page.dart';
import 'package:happy/widgets/cards/concours_card.dart';
import 'package:happy/widgets/cards/deals_express_card.dart';
import 'package:happy/widgets/cards/emploi_card.dart';
import 'package:happy/widgets/cards/evenement_card.dart';
import 'package:happy/widgets/cards/happy_deals_card.dart';
import 'package:happy/widgets/cards/news_card.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';
import 'package:happy/widgets/cards/product_cards.dart';
import 'package:happy/widgets/cards/promo_code_card.dart';
import 'package:happy/widgets/cards/service_cards.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:visibility_detector/visibility_detector.dart';

class PostWidget extends StatefulWidget {
  final Ad? ad;
  final Post post;
  final String currentUserId;
  final String currentProfileUserId;
  final VoidCallback onView;
  final CompanyData companyData;
  final Map<String, dynamic>? sharedByUserData;

  const PostWidget({
    super.key,
    this.ad,
    required this.post,
    required this.currentUserId,
    required this.currentProfileUserId,
    required this.onView,
    required this.companyData,
    this.sharedByUserData,
  });

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

// Classe pour encapsuler les données de l'entreprise
class CompanyData {
  final String name;
  final String category;
  final String logo;
  final String cover;
  final Map<String, dynamic> rawData;

  const CompanyData({
    required this.name,
    required this.category,
    required this.logo,
    required this.cover,
    required this.rawData,
  });
}

class _PostWidgetState extends State<PostWidget>
    with AutomaticKeepAliveClientMixin {
  // State variables
  late final PostStateManager _stateManager;
  bool _isDisposed = false;
  static final Map<String, Post> _postCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    _stateManager = PostStateManager(
      postId: widget.post.id,
      currentUserId: widget.currentUserId,
      onStateChanged: () {
        if (!_isDisposed) setState(() {});
      },
    );
    _stateManager.initialize();
    _postCache[widget.post.id] = widget.post;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return VisibilityDetector(
      key: Key(widget.post.id),
      onVisibilityChanged: _handleVisibilityChanged,
      child: RepaintBoundary(
        child: _PostCard(
          post: _postCache[widget.post.id] ?? widget.post,
          stateManager: _stateManager,
          companyData: widget.companyData,
          sharedByUserData: widget.sharedByUserData,
          currentUserId: widget.currentUserId,
          currentProfileUserId: widget.currentProfileUserId,
          onView: widget.onView,
        ),
      ),
    );
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction > 0.5) {
      _stateManager.incrementViews();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stateManager.dispose();
    super.dispose();
  }
}

// Gestionnaire d'état du post
class PostStateManager {
  final String postId;
  final String currentUserId;
  final VoidCallback onStateChanged;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> _viewedBy = [];
  bool _isLoading = false;
  StreamSubscription? _postSubscription;

  PostStateManager({
    required this.postId,
    required this.currentUserId,
    required this.onStateChanged,
  });

  Future<void> initialize() async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        _viewedBy = List<String>.from(doc.data()?['viewedBy'] ?? []);
        onStateChanged();
      }
      _setupPostListener();
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation: $e');
    }
  }

  void _setupPostListener() {
    _postSubscription =
        _firestore.collection('posts').doc(postId).snapshots().listen((doc) {
      if (doc.exists) {
        _viewedBy = List<String>.from(doc.data()?['viewedBy'] ?? []);
        onStateChanged();
      }
    });
  }

  Future<void> incrementViews() async {
    if (_isLoading || _viewedBy.contains(currentUserId)) return;

    _isLoading = true;
    try {
      await _firestore.collection('posts').doc(postId).update({
        'views': FieldValue.increment(1),
        'viewedBy': FieldValue.arrayUnion([currentUserId])
      });
      _viewedBy.add(currentUserId);
    } catch (e) {
      debugPrint('Erreur lors de l\'incrémentation des vues: $e');
    } finally {
      _isLoading = false;
      onStateChanged();
    }
  }

  void dispose() {
    _postSubscription?.cancel();
  }
}

// Widget principal de la carte
class _PostCard extends StatelessWidget {
  final Post post;
  final PostStateManager stateManager;
  final CompanyData companyData;
  final Map<String, dynamic>? sharedByUserData;
  final String currentUserId;
  final String currentProfileUserId;
  final VoidCallback onView;

  const _PostCard({
    required this.post,
    required this.stateManager,
    required this.companyData,
    required this.currentUserId,
    required this.currentProfileUserId,
    required this.onView,
    this.sharedByUserData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post is SharedPost)
            _SharedPostHeader(
              post: post as SharedPost,
              userData: sharedByUserData,
              currentUserId: currentUserId,
            )
          else
            _CompanyHeader(
              post: post,
              companyData: companyData,
              timestamp: post.timestamp,
            ),
          _PostContent(
            post: post,
            companyData: companyData,
            currentUserId: currentUserId,
          ),
          _InteractionBar(
            post: post,
            currentUserId: currentUserId,
            companyData: companyData,
          ),
        ],
      ),
    );
  }
}

// Composants individuels
class _CompanyHeader extends StatelessWidget {
  final CompanyData companyData;
  final Post post;
  final DateTime timestamp;

  const _CompanyHeader({
    required this.companyData,
    required this.post,
    required this.timestamp,
  });

  String _getPostType() {
    switch (post.runtimeType) {
      case Event:
        return 'Événement';
      case PromoCodePost:
        return 'Code Promo';
      case ProductPost:
        return 'Produit';
      case Referral:
        return 'Parrainage';
      case JobOffer:
        return 'Emplois';
      case Contest:
        return 'Jeux Concours';
      case HappyDeal:
        return 'Happy Deals';
      case ExpressDeal:
        return 'Deal Express';
      case ServicePost:
        return 'Services';
      default:
        return 'Publication';
    }
  }

  LinearGradient _getPostTypeGradient() {
    switch (post.runtimeType) {
      case Event:
        return const LinearGradient(
          colors: [Colors.orange, Colors.pink],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case PromoCodePost:
        return const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ProductPost:
        return const LinearGradient(
          colors: [
            Color.fromARGB(255, 234, 46, 159),
            Color.fromARGB(255, 237, 23, 109)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case Referral:
        return const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case JobOffer:
        return const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case Contest:
        return const LinearGradient(
          colors: [Color(0xFFC62828), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case HappyDeal:
        return const LinearGradient(
          colors: [Color(0xFF00796B), Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ExpressDeal:
        return const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ServicePost:
        return const LinearGradient(
          colors: [Color(0xFF6B48FF), Color(0xFF8466FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  IconData _getPostTypeIcon() {
    switch (post.runtimeType) {
      case Event:
        return Icons.calendar_today_outlined;
      case PromoCodePost:
        return Icons.confirmation_number;
      case ProductPost:
        return Icons.shopping_bag_outlined;
      case Referral:
        return Icons.people_outline;
      case JobOffer:
        return Icons.work_outline;
      case Contest:
        return Icons.emoji_events;
      case HappyDeal:
        return Icons.local_offer;
      case ExpressDeal:
        return Icons.flash_on;
      case ServicePost:
        return Icons.calendar_today_outlined;
      default:
        return Icons.post_add;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailsEntreprise(
              entrepriseId: post.companyId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF3476B2),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(companyData.logo),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyData.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: _getPostTypeGradient(),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getPostTypeIcon(),
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getPostType(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(timestamp, locale: 'fr'),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedPostHeader extends StatelessWidget {
  final SharedPost post;
  final Map<String, dynamic>? userData;
  final String currentUserId;

  const _SharedPostHeader({
    required this.post,
    required this.userData,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final sharedText = post.comment == "a publié une annonce"
        ? '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''} a publié une annonce'
        : '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''} a partagé';

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: GestureDetector(
            onTap: () => _navigateToUserProfile(context, post.sharedBy!),
            child: CircleAvatar(
              backgroundImage:
                  NetworkImage(userData?['userProfilePicture'] ?? ''),
              backgroundColor: Colors.grey,
              onBackgroundImageError: (exception, stackTrace) {
                debugPrint('Erreur de chargement image: $exception');
              },
            ),
          ),
          title: GestureDetector(
            onTap: () => _navigateToUserProfile(context, post.sharedBy!),
            child: Text(
              sharedText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          subtitle: Text(timeago.format(post.sharedAt!, locale: 'fr')),
          trailing: post.sharedBy == currentUserId
              ? IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showOptionsBottomSheet(context, post),
                )
              : null,
        ),
        if (post.comment != "a publié une annonce" &&
            post.comment != null &&
            post.comment!.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(post.comment!),
          ),
      ],
    );
  }

  void _navigateToUserProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Profile(userId: userId),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context, SharedPost post) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Wrap(
          children: <Widget>[
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
                _updatePostComment(post, controller.text, context);
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
                _deleteSharedPost(post, context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _updatePostComment(
      SharedPost post, String newComment, BuildContext context) async {
    try {
      await Provider.of<UserModel>(context, listen: false)
          .updateSharedPostComment(post.id, newComment);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commentaire mis à jour avec succès')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erreur lors de la mise à jour du commentaire')),
      );
    }
  }

  Future<void> _deleteSharedPost(SharedPost post, BuildContext context) async {
    try {
      await Provider.of<UserModel>(context, listen: false)
          .deleteSharedPost(post.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partage supprimé avec succès')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erreur lors de la suppression du partage')),
      );
    }
  }
}

class _PostContent extends StatelessWidget {
  final Post post;
  final CompanyData companyData;
  final String currentUserId;

  const _PostContent({
    required this.post,
    required this.companyData,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (post is SharedPost) {
      return _buildSharedPostContent(post as SharedPost);
    } else {
      return _buildPostTypeContent(post);
    }
  }

  Widget _buildSharedPostContent(SharedPost sharedPost) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection(
              sharedPost.comment == "a publié une annonce" ? 'ads' : 'posts')
          .doc(sharedPost.originalPostId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Erreur de chargement du post');
        }

        if (sharedPost.comment == "a publié une annonce") {
          return _buildAdContent(snapshot.data!);
        } else {
          final originalPost = Post.fromDocument(snapshot.data!);
          return Container(
            child: _buildPostTypeContent(originalPost),
          );
        }
      },
    );
  }

  Widget _buildAdContent(DocumentSnapshot snapshot) {
    return FutureBuilder<Ad>(
      future: Ad.fromFirestore(snapshot),
      builder: (context, adSnapshot) {
        if (adSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (adSnapshot.hasError || !adSnapshot.hasData) {
          return const Text('Erreur de chargement de l\'annonce');
        }

        final ad = adSnapshot.data!;
        return AdCard(
          ad: ad,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdDetailPage(ad: ad)),
          ),
          onSaveTap: () => _toggleSaveAd(ad, context),
        );
      },
    );
  }

  Future<void> _toggleSaveAd(Ad ad, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Vous devez être connecté pour sauvegarder une annonce')),
      );
      return;
    }

    try {
      final savedAdsProvider =
          Provider.of<SavedAdsProvider>(context, listen: false);
      await savedAdsProvider.toggleSaveAd(user.uid, ad.id);
    } catch (e) {
      if (!context.mounted) return;
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
        );
      case Contest:
        return ConcoursCard(
          contest: post as Contest,
          currentUserId: currentUserId,
        );
      case HappyDeal:
        return HappyDealsCard(
          post: post as HappyDeal,
          companyName: companyData.name,
          companyCover: companyData.cover,
          companyCategorie: companyData.category,
          companyLogo: companyData.logo,
        );
      case News:
        return NewsCard(
          news: post as News,
          companyName: companyData.name,
          companyLogo: companyData.logo,
        );
      case Referral:
        return ParrainageCard(
          post: post as Referral,
          currentUserId: currentUserId,
          companyName: companyData.name,
          companyLogo: companyData.logo,
        );
      case ExpressDeal:
        return DealsExpressCard(
          currentUserId: currentUserId,
          post: post as ExpressDeal,
          companyName: companyData.name,
          companyLogo: companyData.logo,
        );
      case ProductPost:
        return ProductCards(
          post: post as ProductPost,
          companyName: companyData.name,
          companyLogo: companyData.logo,
        );
      case ServicePost:
        return ServiceCards(
          post: post as ServicePost,
          companyName: companyData.name,
          companyLogo: companyData.logo,
        );
      case Event:
        return EvenementCard(
          event: post as Event,
          currentUserId: currentUserId,
          companyName: companyData.name,
          companyLogo: companyData.logo,
        );
      case PromoCodePost:
        return PromoCodeCard(
          post: post as PromoCodePost,
          companyName: companyData.name,
          companyLogo: companyData.logo,
          currentUserId: currentUserId,
        );

      // ... autres cas similaires ...
      default:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type de post non supporté: ${post.runtimeType}'),
                Text('ID du post: ${post.id}'),
                Text('Entreprise: ${companyData.name}'),
                Text('Catégorie: ${companyData.category}'),
              ],
            ),
          ),
        );
    }
  }
}

class _InteractionBar extends StatelessWidget {
  final Post post;
  final String currentUserId;
  final CompanyData companyData;

  const _InteractionBar({
    required this.post,
    required this.currentUserId,
    required this.companyData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id)
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
        final isLiked = likedBy.contains(currentUserId);

        return Consumer<UserModel>(
          builder: (context, userModel, _) {
            final isCurrentUser = post is SharedPost &&
                (post as SharedPost).sharedBy == currentUserId;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          LikeButton(
                            isLiked: isLiked,
                            onTap: () async {
                              await _handleLike(userModel);
                              return !isLiked;
                            },
                            likeCount: likes,
                          ),
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
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleLike(UserModel userModel) async {
    try {
      await userModel.handleLike(post);
    } catch (e) {
      debugPrint('Erreur lors du like: $e');
    }
  }

  void _navigateToComments(BuildContext context) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            Future<void> sendComment() async {
              if (commentController.text.trim().isEmpty) return;

              try {
                final comment = {
                  'userId': currentUserId,
                  'text': commentController.text.trim(),
                  'timestamp': Timestamp.now(),
                };

                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.id)
                    .update({
                  'comments': FieldValue.arrayUnion([comment]),
                  'commentsCount': FieldValue.increment(1),
                });

                commentController.clear();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Commentaire ajouté'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Erreur lors de l\'envoi du commentaire: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erreur lors de l\'envoi du commentaire'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Commentaires',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('posts')
                            .doc(post.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final comments = (snapshot.data!.data()
                                  as Map<String, dynamic>)['comments'] ??
                              [];

                          if (comments.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Aucun commentaire pour le moment',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Soyez le premier à commenter !',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(comment['userId'])
                                    .get(),
                                builder: (context, userSnapshot) {
                                  if (!userSnapshot.hasData) {
                                    return const SizedBox.shrink();
                                  }

                                  final userData = userSnapshot.data!.data()
                                      as Map<String, dynamic>;
                                  final timestamp =
                                      comment['timestamp'] is Timestamp
                                          ? (comment['timestamp'] as Timestamp)
                                              .toDate()
                                          : DateTime.now();

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage: NetworkImage(
                                            userData['image_profile'] ?? '',
                                          ),
                                          backgroundColor: Colors.grey[200],
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    '${userData['firstName']} ${userData['lastName']}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    timeago.format(timestamp,
                                                        locale: 'fr'),
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(comment['text']),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                decoration: InputDecoration(
                                  hintText: 'Ajouter un commentaire...',
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide:
                                        BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide:
                                        BorderSide(color: Colors.blue[700]!),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue[700]!,
                                    Colors.blue[400]!
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.send_rounded),
                                color: Colors.white,
                                onPressed: sendComment,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      commentController.dispose();
    });
  }

  void _showShareConfirmation(BuildContext context, UserModel users) {
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ShareConfirmationDialog(
          post: post,
          onConfirm: (String comment) async {
            try {
              Navigator.of(dialogContext).pop();

              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(post.id)
                  .update({
                'sharesCount': FieldValue.increment(1),
              });

              await users.sharePost(
                post.id,
                users.userId,
                comment: comment,
              );

              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                  const SnackBar(
                    content: Text('Publication partagée avec succès!'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (scaffoldContext.mounted) {
                ScaffoldMessenger.of(scaffoldContext).showSnackBar(
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
  }
}

class LikeButton extends StatefulWidget {
  final bool isLiked;
  final Future<bool> Function() onTap;
  final int likeCount;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
    required this.likeCount,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isLiked = widget.isLiked;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    _controller.forward().then((_) => _controller.reverse());
    final newIsLiked = await widget.onTap();
    if (mounted) {
      setState(() {
        _isLiked = newIsLiked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : Icons.favorite_border,
              color: _isLiked ? Colors.red : null,
            ),
            onPressed: _handleTap,
          ),
        ),
        Text('${widget.likeCount}'),
      ],
    );
  }
}
