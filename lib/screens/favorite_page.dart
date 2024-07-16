import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:provider/provider.dart';

class Favorite extends StatefulWidget {
  const Favorite({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FavoriteState createState() => _FavoriteState();
}

class _FavoriteState extends State<Favorite> {
  Future<List<DocumentSnapshot>> _getLikedPosts(List<String> likedPost) async {
    List<Future<DocumentSnapshot>> futures = likedPost.map((postId) {
      return FirebaseFirestore.instance
          .collection('companys')
          .doc(postId)
          .get();
    }).toList();

    List<DocumentSnapshot> documents = await Future.wait(futures);
    return documents;
  }

  @override
  Widget build(BuildContext context) {
    final likedPost = Provider.of<UserModel>(context).likedPosts;

    return FutureBuilder<List<DocumentSnapshot>>(
      future: _getLikedPosts(likedPost),
      builder: (BuildContext context,
          AsyncSnapshot<List<DocumentSnapshot>> snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading");
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text("No liked posts found");
        }

        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text('Mes Likes'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
