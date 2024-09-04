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
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildPostsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Erreur: ${snapshot.error}');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Utilisateur non trouvé');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      NetworkImage(userData['image_profile'] ?? ''),
                ),
                const SizedBox(height: 16),
                Text(
                  '${userData['firstName']} ${userData['lastName']}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Identifiant : ${userData['uniqueCode']}'),
                const SizedBox(height: 16),
                _buildFollowButton(widget.userId),
              ],
            ),
          ),
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
          return ElevatedButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GeneralProfilePage()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: const Text('Modifier mon profil'),
          );
        }

        return ElevatedButton(
          onPressed: () {
            if (isFollowing) {
              userModel.unfollowUser(profileUserId);
            } else {
              userModel.followUser(profileUserId);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey : Colors.blue,
          ),
          child: Text(isFollowing ? 'Se désabonner' : 'S\'abonner'),
        );
      },
    );
  }

  Widget _buildPostsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          print(snapshot.error);
          return Text('Erreur: ${snapshot.error}');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('Aucun post partagé');
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
                  return const CircularProgressIndicator();
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
