import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/rating.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/post_type_page/professional_page.dart';
import 'package:happy/screens/troc-et-echange/ad_card.dart';
import 'package:happy/screens/troc-et-echange/ad_detail_page.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/rating_dialog.dart';
import 'package:provider/provider.dart';

class Profile extends StatefulWidget {
  final String userId;

  const Profile({super.key, required this.userId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _postsStream;
  late Stream<QuerySnapshot> _adsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initStreams();
  }

  void _initStreams() {
    final firestore = FirebaseFirestore.instance;
    _userStream = firestore.collection('users').doc(widget.userId).snapshots();
    _postsStream = firestore
        .collection('posts')
        .where('sharedBy', isEqualTo: widget.userId)
        .orderBy('sharedAt', descending: true)
        .snapshots();
    _adsStream = firestore
        .collection('ads')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double coverHeight = 200.0; // Hauteur de l'image de couverture

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Profil non trouvé'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final userName =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                  .trim();

          return NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  floating: false,
                  pinned: true,
                  expandedHeight: coverHeight,
                  flexibleSpace: FlexibleSpaceBar(
                    title: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                      child: Text(userName),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image de couverture
                        userData['coverImage'] != null &&
                                userData['coverImage'].isNotEmpty
                            ? Image.network(
                                userData['coverImage'],
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                'assets/images/UP.png', // Créez une image par défaut
                                fit: BoxFit.cover,
                              ),
                        // Overlay avec dégradé
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                        // Overlay avec opacité
                        Container(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: innerBoxIsScrolled ? 1 : 0,
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildProfileHeader(userData),
                      _buildTabBar(),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsList(),
                _buildAdsList(),
                _buildRatingsList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingsList() {
    return StreamBuilder<List<Rating>>(
      stream: Provider.of<ConversationService>(context, listen: false)
          .getUserRatings(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune évaluation'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final rating = snapshot.data![index];
            return _buildRatingCard(rating);
          },
        );
      },
    );
  }

  Widget _buildRatingCard(Rating rating) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(rating.fromUserId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final userName = '${userData['firstName']} ${userData['lastName']}';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Photo de profil cliquable
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                Profile(userId: rating.fromUserId),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        backgroundImage:
                            NetworkImage(userData['image_profile'] ?? ''),
                        radius: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Informations utilisateur
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      Profile(userId: rating.fromUserId),
                                ),
                              );
                            },
                            child: Text(
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            rating.isSellerRating ? 'Vendeur' : 'Acheteur',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    // Étoiles
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating.rating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        );
                      }),
                    ),
                    // Bouton modifier si c'est notre avis
                    if (currentUserId == rating.fromUserId)
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Modifier l\'évaluation'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    showDialog(
                                      context: context,
                                      builder: (context) => RatingDialog(
                                        adId: rating.adId,
                                        adTitle: rating.adTitle,
                                        toUserId: rating.toUserId,
                                        conversationId: rating.conversationId,
                                        isSellerRating: rating.isSellerRating,
                                        existingRating: rating,
                                      ),
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete,
                                      color: Colors.red),
                                  title: const Text('Supprimer l\'évaluation',
                                      style: TextStyle(color: Colors.red)),
                                  onTap: () async {
                                    Navigator.pop(context);
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text(
                                            'Supprimer l\'évaluation'),
                                        content: const Text(
                                            'Êtes-vous sûr de vouloir supprimer cette évaluation ?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Annuler'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Supprimer',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await Provider.of<ConversationService>(
                                                context,
                                                listen: false)
                                            .deleteRating(rating.id);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Évaluation supprimée avec succès')),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'Erreur lors de la suppression: $e')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
                if (rating.adTitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Article : ${rating.adTitle}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
                if (rating.comment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(rating.comment),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatDate(rating.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    // Vous pouvez utiliser le même format que celui utilisé ailleurs dans votre application
    return '${date.day}/${date.month}/${date.year}';
  }

  TabBar _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Posts partagés'),
        Tab(text: 'Annonces'),
        Tab(text: 'Évaluations'),
      ],
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    return Consumer<UserModel>(
      builder: (context, userModel, _) {
        final bool isCurrentUser = userModel.userId == widget.userId;

        // Vérification si c'est un particulier (vérifie si c'est un particulier en regardant s'il a un prénom)
        final bool isIndividual = userData['firstName'] != null;

        // Conversion sécurisée des listes d'abonnements
        List<String> userFollowedUsers = [];
        if (userData['followedUsers'] is List) {
          userFollowedUsers = List<String>.from(userData['followedUsers']);
        }

        // Vérification abonnement mutuel ET si c'est un particulier
        final bool isMutualFollow = !isCurrentUser &&
            isIndividual &&
            userModel.followedUsers.contains(widget.userId) && // Je le suis
            userFollowedUsers.contains(userModel.userId); // Il me suit

        debugPrint('Current User ID: ${userModel.userId}');
        debugPrint('Profile User ID: ${widget.userId}');
        debugPrint('Is Individual: $isIndividual');
        debugPrint(
            'Is Current User following Profile: ${userModel.followedUsers.contains(widget.userId)}');
        debugPrint(
            'Is Profile following Current User: ${userFollowedUsers.contains(userModel.userId)}');
        debugPrint('Is Mutual Follow: $isMutualFollow');

        // Peut voir l'identifiant seulement si c'est le propriétaire du profil ou un abonnement mutuel avec un particulier
        final bool canSeeUniqueCode =
            isCurrentUser || (isMutualFollow && isIndividual);

        // Débug de l'affichage du code unique
        debugPrint('Can See Unique Code: $canSeeUniqueCode');
        debugPrint('Has Unique Code: ${userData['uniqueCode'] != null}');
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileImage(userData['image_profile'] as String?),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                              .trim(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Afficher l'identifiant uniquement en cas d'abonnement mutuel
                        if (canSeeUniqueCode &&
                            userData['uniqueCode'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                userData['uniqueCode'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              IconButton(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.help_outline,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () => _showIdentifierInfo(context),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildFollowButton(widget.userId, userModel),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildUserStats(userData),
            ],
          ),
        );
      },
    );
  }

  void _showIdentifierInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'À propos de l\'identifiant',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Votre identifiant unique est un code qui vous permet d\'être facilement identifiable par d\'autres utilisateurs. Il peut être utilisé pour :',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoPoint('Partager votre profil facilement'),
              _buildInfoPoint('Être retrouvé par vos amis'),
              _buildInfoPoint('Sécuriser votre compte'),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProfileImage(String? imageUrl) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.blue[600]!,
          width: 3,
        ),
      ),
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey[200],
        backgroundImage: imageUrl != null && imageUrl.isNotEmpty
            ? NetworkImage(imageUrl)
            : null,
        child: imageUrl == null || imageUrl.isEmpty
            ? const Icon(Icons.person, size: 50, color: Colors.grey)
            : null,
      ),
    );
  }

  Widget _buildUserStats(Map<String, dynamic> userData) {
    return FutureBuilder<Map<String, int>>(
      future: _getCounts(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Erreur: ${snapshot.error}');
        }

        final counts = snapshot.data ?? {'ads': 0, 'sharedPosts': 0};

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Posts partagés', counts['sharedPosts'] ?? 0),
            _buildStatItem('Annonces', counts['ads'] ?? 0),
            GestureDetector(
              onTap: () => _showFollowersList(
                  context, (userData['followers'] as List?) ?? []),
              child: _buildStatItem(
                  'Abonnés', (userData['followers'] as List?)?.length ?? 0),
            ),
            GestureDetector(
              onTap: () => _showFollowingList(
                  context, (userData['followedUsers'] as List?) ?? []),
              child: _buildStatItem('Abonnements',
                  (userData['followedUsers'] as List?)?.length ?? 0),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, int>> _getCounts(String userId) async {
    final adsSnapshot = await FirebaseFirestore.instance
        .collection('ads')
        .where('userId', isEqualTo: userId)
        .get();

    final sharedPostsSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('sharedBy', isEqualTo: userId)
        .get();

    return {
      'ads': adsSnapshot.size,
      'sharedPosts': sharedPostsSnapshot.size,
    };
  }

  Widget _buildFollowButton(String profileUserId, UserModel userModel) {
    bool isFollowing = userModel.followedUsers.contains(profileUserId);
    bool isCurrentUser = userModel.userId == profileUserId;

    if (isCurrentUser) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: TextButton.icon(
          icon: const Icon(
            Icons.edit_outlined,
            size: 16,
            color: Colors.black,
          ),
          label: const Text(
            'Modifier mon profil',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GeneralProfilePage()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.centerLeft,
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      icon: Icon(
        isFollowing ? Icons.person : Icons.person_add,
        size: 18,
        color: Colors.black,
      ),
      label: Text(
        isFollowing ? 'Abonné' : 'S\'abonner',
        style: const TextStyle(fontSize: 14, color: Colors.black),
      ),
      onPressed: () {
        if (!isFollowing) {
          userModel.followUser(profileUserId);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isFollowing ? Colors.grey[100] : Colors.blue[600],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _showFollowersList(BuildContext context, List followers) {
    _showUserList(context, 'Abonnés', followers, canRemove: true);
  }

  void _showFollowingList(BuildContext context, List followedUsers) {
    _showUserList(context, 'Abonnements', followedUsers, canUnfollow: true);
  }

  void _showUserList(BuildContext context, String title, List users,
      {bool canRemove = false, bool canUnfollow = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: users.length,
                      itemBuilder: (context, index) => _buildUserListItem(
                          users[index],
                          canRemove: canRemove,
                          canUnfollow: canUnfollow),
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

  Widget _buildUserListItem(String userId,
      {bool canRemove = false, bool canUnfollow = false}) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text('Chargement...'),
          );
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(userData['image_profile'] ?? ''),
            backgroundColor: Colors.grey,
            child: userData['image_profile'] == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          title: Text('${userData['firstName']} ${userData['lastName']}'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Profile(userId: userId)),
          ),
          trailing: _buildUserListItemTrailing(userId, canRemove, canUnfollow),
        );
      },
    );
  }

  Widget? _buildUserListItemTrailing(
      String userId, bool canRemove, bool canUnfollow) {
    final currentUserId = Provider.of<UserModel>(context, listen: false).userId;
    if (canRemove && currentUserId == widget.userId) {
      return IconButton(
        icon: const Icon(Icons.person_remove),
        onPressed: () => _removeFollower(userId),
      );
    } else if (canUnfollow && currentUserId == widget.userId) {
      return ElevatedButton(
        child: const Text('Se désabonner'),
        onPressed: () => _unfollowUser(userId),
      );
    }
    return null;
  }

  void _removeFollower(String followerId) {
    Provider.of<UserModel>(context, listen: false)
        .removeFollower(followerId)
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abonné supprimé avec succès')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Erreur lors de la suppression de l\'abonné: $error')),
      );
    });
  }

  void _unfollowUser(String userId) {
    Provider.of<UserModel>(context, listen: false)
        .unfollowUser(userId)
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Désabonnement effectué avec succès')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du désabonnement: $error')),
      );
    });
  }

  Widget _buildPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun post partagé'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final postDoc = snapshot.data!.docs[index];
            final post = Post.fromDocument(postDoc);

            // Vérifiez si c'est un post partagé avec une annonce
            if (post is SharedPost && post.comment == "a publié une annonce") {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('ads')
                    .doc(post.originalPostId)
                    .get(),
                builder: (context, adSnapshot) {
                  if (adSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (adSnapshot.hasError ||
                      !adSnapshot.hasData ||
                      !adSnapshot.data!.exists) {
                    return const SizedBox
                        .shrink(); // Gestion des erreurs de chargement de l'annonce
                  }

                  // Utilisation d'un autre FutureBuilder pour attendre l'objet `Ad`
                  return FutureBuilder<Ad>(
                    future: Ad.fromFirestore(adSnapshot
                        .data!), // Attente du chargement complet de l'Ad
                    builder: (context, adObjectSnapshot) {
                      if (adObjectSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (adObjectSnapshot.hasError ||
                          !adObjectSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final ad = adObjectSnapshot.data!;
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (userSnapshot.hasError || !userSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          final userData =
                              userSnapshot.data!.data() as Map<String, dynamic>;

// Créez la structure correcte pour sharedByUserData qui correspond à celle attendue par PostWidget
                          final formattedUserData = {
                            'firstName': userData['firstName'] ?? '',
                            'lastName': userData['lastName'] ?? '',
                            'userProfilePicture': userData['image_profile'] ??
                                '', // Assurez-vous d'utiliser la même clé 'image_profile'
                          };
                          return PostWidget(
                            key: ValueKey(post.id),
                            post: post,
                            ad: ad,
                            companyCover: '',
                            companyCategorie: '',
                            companyName: '',
                            companyLogo: '',
                            currentUserId: widget.userId,
                            sharedByUserData: formattedUserData,
                            currentProfileUserId: widget.userId,
                            onView: () {
                              // Logique d'affichage de l'annonce
                            },
                            companyData: const {},
                          );
                        },
                      );
                    },
                  );
                },
              );
            } else {
              // Traitement pour les autres types de posts (JobOffer, Contest, etc.)
              return FutureBuilder<List<DocumentSnapshot>>(
                future: Future.wait([
                  FirebaseFirestore.instance
                      .collection('companys')
                      .doc(post.companyId)
                      .get(),
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.userId)
                      .get(),
                ]),
                builder: (context, snapshots) {
                  if (snapshots.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshots.hasError ||
                      !snapshots.hasData ||
                      snapshots.data!.any((snapshot) => !snapshot.exists)) {
                    return const SizedBox.shrink();
                  }

                  final companyData =
                      snapshots.data![0].data() as Map<String, dynamic>;
                  final userData =
                      snapshots.data![1].data() as Map<String, dynamic>;

                  final formattedUserData = {
                    'firstName': userData['firstName'] ?? '',
                    'lastName': userData['lastName'] ?? '',
                    'userProfilePicture': userData['image_profile'] ??
                        '', // Assurez-vous d'utiliser la même clé 'image_profile'
                  };

                  return PostWidget(
                    key: ValueKey(post.id),
                    post: post,
                    companyCover: companyData['cover'],
                    companyCategorie: companyData['categorie'] ?? '',
                    companyName: companyData['name'] ?? '',
                    companyLogo: companyData['logo'] ?? '',
                    currentUserId: widget.userId,
                    sharedByUserData: formattedUserData,
                    currentProfileUserId: widget.userId,
                    onView: () {
                      // Logique d'affichage du post
                    },
                    companyData: companyData,
                  );
                },
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAdsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _adsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucune annonce publiée'));
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          padding: const EdgeInsets.all(10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot doc = snapshot.data!.docs[index];
            return FutureBuilder<Ad>(
              future: Ad.fromFirestore(doc),
              builder: (context, adSnapshot) {
                if (adSnapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (adSnapshot.hasError || !adSnapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final ad = adSnapshot.data!;
                return AdCard(
                  ad: ad,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdDetailPage(ad: ad),
                      ),
                    );
                  },
                  onSaveTap: () => _toggleSaveAd(ad),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _toggleSaveAd(Ad ad) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Vous devez être connecté pour sauvegarder une annonce')),
      );
      return;
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        List<String> savedAds =
            List<String>.from(userDoc.data()?['savedAds'] ?? []);

        if (savedAds.contains(ad.id)) {
          savedAds.remove(ad.id);
        } else {
          savedAds.add(ad.id);
        }

        transaction.update(userRef, {'savedAds': savedAds});
      });

      setState(() {
        ad.isSaved = !ad.isSaved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ad.isSaved
                ? 'Annonce sauvegardée'
                : 'Annonce retirée des favoris')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    }
  }
}
