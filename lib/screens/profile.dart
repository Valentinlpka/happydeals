import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/post_type_page/professional_page.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class Profile extends StatefulWidget {
  final String userId;

  const Profile({super.key, required this.userId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  late Future<DocumentSnapshot> _userFuture;
  late Stream<QuerySnapshot> _postsStream;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildProfileHeader()),
          SliverToBoxAdapter(child: _buildPostsList()),
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
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                  child: Text('Erreur de chargement du profil'));
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final bool isCurrentUser = userModel.userId == widget.userId;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildProfileImage(userData['image_profile']),
                  const SizedBox(height: 16),
                  Text(
                    '${userData['firstName']} ${userData['lastName']}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (isCurrentUser) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Identifiant : ${userData['uniqueCode']}',
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
          icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add),
          label: Text(isFollowing ? 'Se désabonner' : 'S\'abonner'),
          onPressed: () {
            if (isFollowing) {
              userModel.unfollowUser(profileUserId);
            } else {
              userModel.followUser(profileUserId);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey : Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        );
      },
    );
  }

  Widget _buildUserStats(Map<String, dynamic> userData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Posts', userData['postsCount'] ?? 0),
        _buildStatItem(
            'Abonnés', (userData['followedUsers'] as List).length ?? 0),
        _buildStatItem(
            'Abonnements', (userData['followedUsers'] as List).length ?? 0),
      ],
    );
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
