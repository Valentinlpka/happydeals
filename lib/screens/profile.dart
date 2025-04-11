import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/post_type_page/professional_page.dart';
import 'package:happy/screens/troc-et-echange/ad_card.dart';
import 'package:happy/screens/troc-et-echange/ad_detail_page.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class Profile extends StatefulWidget {
  final String userId;

  const Profile({super.key, required this.userId});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _postsStream;
  late Stream<QuerySnapshot> _adsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    const double coverHeight = 200.0;

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
                        _buildCoverImage(userData),
                        _buildCoverOverlay(),
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
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoverImage(Map<String, dynamic> userData) {
    return userData['coverImage'] != null && userData['coverImage'].isNotEmpty
        ? Image.network(
            userData['coverImage'],
            fit: BoxFit.cover,
          )
        : Image.asset(
            'assets/images/UP.png',
            fit: BoxFit.cover,
          );
  }

  Widget _buildCoverOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(30),
            Colors.black.withAlpha(50),
          ],
        ),
      ),
    );
  }

  TabBar _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Posts partagés'),
        Tab(text: 'Annonces'),
      ],
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    return Consumer<UserModel>(
      builder: (context, userModel, _) {
        final userName =
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim();

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
                          userName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
            _buildStatItem(
                'Abonnés', (userData['followers'] as List?)?.length ?? 0),
            _buildStatItem('Abonnements',
                (userData['followedUsers'] as List?)?.length ?? 0),
          ],
        );
      },
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

  Widget _buildPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream.distinct(),
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
            return _buildPostItem(post, postDoc.id);
          },
        );
      },
    );
  }

  Widget _buildPostItem(Post post, String postId) {
    if (post is SharedPost && post.comment == "a publié une annonce") {
      return _buildAdPostItem(post, postId);
    } else {
      return _buildRegularPostItem(post, postId);
    }
  }

  Widget _buildAdPostItem(SharedPost post, String postId) {
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
          return const SizedBox.shrink();
        }

        return FutureBuilder<Ad>(
          future: Ad.fromFirestore(adSnapshot.data!),
          builder: (context, adObjectSnapshot) {
            if (adObjectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (adObjectSnapshot.hasError || !adObjectSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            return _buildPostWidgetWithUserData(
              post,
              postId,
              ad: adObjectSnapshot.data!,
            );
          },
        );
      },
    );
  }

  Widget _buildRegularPostItem(Post post, String postId) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance
            .collection('companys')
            .doc(post.companyId)
            .get(),
        FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
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

        final companyData = snapshots.data![0].data() as Map<String, dynamic>;
        final userData = snapshots.data![1].data() as Map<String, dynamic>;

        return _buildPostWidgetWithUserData(
          post,
          postId,
          companyData: companyData,
          userData: userData,
        );
      },
    );
  }

  Widget _buildPostWidgetWithUserData(
    Post post,
    String postId, {
    Ad? ad,
    Map<String, dynamic>? companyData,
    Map<String, dynamic>? userData,
  }) {
    final formattedUserData = userData != null
        ? {
            'firstName': userData['firstName'] ?? '',
            'lastName': userData['lastName'] ?? '',
            'userProfilePicture': userData['image_profile'] ?? '',
          }
        : null;

    return PostWidget(
      key: ValueKey('${postId}_${DateTime.now().millisecondsSinceEpoch}'),
      post: post,
      ad: ad,
      companyData: CompanyData(
          category: companyData?['categorie'] ?? '',
          cover: companyData?['cover'] ?? '',
          logo: companyData?['logo'] ?? '',
          name: companyData?['name'] ?? '',
          rawData: companyData ?? {}),
      currentUserId: widget.userId,
      sharedByUserData: formattedUserData,
      currentProfileUserId: widget.userId,
      onView: () {},
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
      if (!mounted) return;
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
