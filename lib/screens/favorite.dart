import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/company_card.dart';
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
    final likedPost = Provider.of<Users>(context).likeList;

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

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Text('Mes Likes'),
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: snapshot.data!.map((DocumentSnapshot document) {
                      if (!document.exists) return Container();
                      Map<String, dynamic> data =
                          document.data()! as Map<String, dynamic>;
                      return CompanyCard(Company(
                        id: document.id,
                        name: data['name'],
                        categorie: data['categorie'],
                        open: true,
                        rating: 3,
                        like: 400,
                        ville: 'Va',
                        phone: data['phone'],
                        logo: '',
                        description: '',
                        website: '',
                        address: '',
                        email: '',
                      ));
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
