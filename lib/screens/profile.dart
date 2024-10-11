import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/marketplace/ad_card.dart';
import 'package:happy/screens/marketplace/ad_detail_page.dart';
import 'package:happy/screens/post_type_page/professional_page.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class Profile extends StatefulWidget {
  final String userId;

  const Profile({super.key, required this.userId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  late Future<DocumentSnapshot> _userFuture;
  late Stream<QuerySnapshot> _postsStream;
  late Stream<QuerySnapshot> _adsStream;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _userFuture =
        FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('sharedBy', isEqualTo: widget.userId)
        .orderBy('sharedAt', descending: true)
        .snapshots();
    _adsStream = FirebaseFirestore.instance
        .collection('ads')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
    _tabController = TabController(
      length: 2,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildProfileHeader()),
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Posts partagés'),
                  Tab(text: 'Annonces'),
                ],
              ),
            ),
            pinned: true,
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostsList(),
                _buildAdsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 100.0,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {}
            return const Text('');
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Consumer<UserModel>(
      builder: (context, userModel, child) {
        return FutureBuilder<DocumentSnapshot>(
          future: _userFuture,
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

            final userData =
                snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final bool isCurrentUser = userModel.userId == widget.userId;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildProfileImage(userData['image_profile'] as String?),
                  const SizedBox(height: 16),
                  Text(
                    '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                        .trim(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (isCurrentUser) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Identifiant : ${userData['uniqueCode'] ?? 'Non défini'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildFollowButton(widget.userId),
                  const SizedBox(height: 16),
                  _buildUserStats(userData),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileImage(String? imageUrl) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey[200],
      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
          ? NetworkImage(imageUrl)
          : null,
      child: imageUrl == null || imageUrl.isEmpty
          ? const Icon(Icons.person, size: 50, color: Colors.grey)
          : null,
    );
  }

  Widget _buildUserStats(Map<String, dynamic> userData) {
    return FutureBuilder<int>(
      future: _getAdsCount(widget.userId),
      builder: (context, snapshot) {
        int adsCount = snapshot.data ?? 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('Posts', userData['postsCount'] as int? ?? 0),
            _buildStatItem('Annonces', adsCount),
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

  Widget _buildFollowButton(String profileUserId) {
    return Consumer<UserModel>(
      builder: (context, userModel, child) {
        bool isFollowing = userModel.followedUsers.contains(profileUserId);
        bool isCurrentUser = userModel.userId == profileUserId;

        if (isCurrentUser) {
          return ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Modifier mon profil'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const GeneralProfilePage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          );
        }

        return ElevatedButton.icon(
          icon: Icon(isFollowing ? Icons.person : Icons.person_add),
          label: Text(isFollowing ? 'Abonné' : 'S\'abonner'),
          onPressed: () {
            if (!isFollowing) {
              userModel.followUser(profileUserId);
            }
            // Nous ne permettons plus le unfollow directement depuis ce bouton
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey : Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        );
      },
    );
  }

  Future<int> _getAdsCount(String userId) async {
    QuerySnapshot adsSnapshot = await FirebaseFirestore.instance
        .collection('ads')
        .where('userId', isEqualTo: userId)
        .get();
    return adsSnapshot.size;
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  void _showFollowersList(BuildContext context, List followers) {
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
                  Text('Abonnés',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: followers.length,
                      itemBuilder: (context, index) {
                        String userId = followers[index];
                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  child:
                                      Icon(Icons.person, color: Colors.white),
                                ),
                                title: Text('Chargement...'),
                              );
                            } else {
                              print(snapshot.error);
                            }

                            var userData =
                                snapshot.data!.data() as Map<String, dynamic>;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(
                                    userData['image_profile'] ?? ''),
                                backgroundColor: Colors.grey,
                                child: userData['image_profile'] == null
                                    ? const Icon(Icons.person,
                                        color: Colors.white)
                                    : null,
                              ),
                              title: Text(
                                  '${userData['firstName']} ${userData['lastName']}'),
                              onTap: () {
                                // Navigation vers le profil de l'abonné
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Profile(userId: userId),
                                  ),
                                );
                              },
                              trailing: widget.userId ==
                                      Provider.of<UserModel>(context,
                                              listen: false)
                                          .userId
                                  ? IconButton(
                                      icon: const Icon(Icons.person_remove),
                                      onPressed: () {
                                        // Logique pour supprimer l'abonné
                                        _removeFollower(userId);
                                      },
                                    )
                                  : null,
                            );
                          },
                        );
                      },
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

  void _removeFollower(String followerId) {
    // Vérifier si l'utilisateur actuel est bien le propriétaire du profil
    if (Provider.of<UserModel>(context, listen: false).userId !=
        widget.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Vous n\'êtes pas autorisé à effectuer cette action')),
      );
      return;
    }

    FirebaseFirestore.instance.runTransaction((transaction) async {
      // Référence du document de l'utilisateur actuel
      DocumentReference currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);

      // Référence du document du follower
      DocumentReference followerRef =
          FirebaseFirestore.instance.collection('users').doc(followerId);

      // Obtenir les données actuelles
      DocumentSnapshot currentUserSnapshot =
          await transaction.get(currentUserRef);
      DocumentSnapshot followerSnapshot = await transaction.get(followerRef);

      if (!currentUserSnapshot.exists || !followerSnapshot.exists) {
        throw Exception('Un des utilisateurs n\'existe pas');
      }

      // Mettre à jour les followers de l'utilisateur actuel
      List<dynamic> currentUserFollowers =
          List.from(currentUserSnapshot['followers'] ?? []);
      if (currentUserFollowers.contains(followerId)) {
        currentUserFollowers.remove(followerId);
        transaction.update(currentUserRef, {'followers': currentUserFollowers});
      }

      // Mettre à jour les followedUsers du follower
      List<dynamic> followerFollowedUsers =
          List.from(followerSnapshot['followedUsers'] ?? []);
      if (followerFollowedUsers.contains(widget.userId)) {
        followerFollowedUsers.remove(widget.userId);
        transaction
            .update(followerRef, {'followedUsers': followerFollowedUsers});
      }
    }).then((_) {
      // Mise à jour de l'interface utilisateur
      setState(() {
        // La liste des abonnés sera mise à jour automatiquement si vous utilisez un StreamBuilder
      });
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

  void _showFollowingList(BuildContext context, List followedUsers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Consumer<UserModel>(
          builder: (context, userModel, child) {
            bool isCurrentUserProfile = userModel.userId == widget.userId;
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
                      Text('Abonnements',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount: followedUsers.length,
                          itemBuilder: (context, index) {
                            String userId = followedUsers[index];
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const LinearProgressIndicator();

                                var userData = snapshot.data!.data()
                                    as Map<String, dynamic>;
                                return ListTile(
                                  onTap: () {
                                    // Navigation vers le profil de l'abonné
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            Profile(userId: userId),
                                      ),
                                    );
                                  },
                                  leading: CircleAvatar(
                                    backgroundImage: NetworkImage(
                                        userData['image_profile'] ?? ''),
                                  ),
                                  title: Text(
                                      '${userData['firstName']} ${userData['lastName']}'),
                                  trailing: isCurrentUserProfile
                                      ? ElevatedButton(
                                          child: const Text('Se désabonner'),
                                          onPressed: () {
                                            userModel.unfollowUser(userId);
                                            setState(() {
                                              followedUsers.remove(userId);
                                            });
                                          },
                                        )
                                      : null,
                                );
                              },
                            );
                          },
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
                );
              },
            );
          },
        );
      },
    );
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
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final postDoc = snapshot.data!.docs[index];
            final post = Post.fromDocument(postDoc);
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
                if (snapshots.hasError || !snapshots.hasData) {
                  return const SizedBox();
                }

                final companyData =
                    snapshots.data![0].data() as Map<String, dynamic>;
                final userData =
                    snapshots.data![1].data() as Map<String, dynamic>;

                return PostWidget(
                  key: ValueKey(post.id),
                  post: post,
                  companyCover: companyData['cover'],
                  companyCategorie: companyData['categorie'] ?? '',
                  companyName: companyData['name'] ?? '',
                  companyLogo: companyData['logo'] ?? '',
                  currentUserId: widget.userId,
                  sharedByUserData: userData,
                  onView: () {
                    // Logique d'affichage du post
                  },
                  companyData: companyData,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
