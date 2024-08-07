import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/widgets/postwidget.dart'; // Assurez-vous d'importer correctement vos widgets de post

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String searchTerm = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recherche"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Rechercher un post...",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(5))),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {
                    searchTerm = value;
                  });
                },
              ),
            ),
            Expanded(
              child: SearchResults(searchTerm: searchTerm),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchResults extends StatelessWidget {
  final String searchTerm;

  const SearchResults({super.key, required this.searchTerm});

  @override
  Widget build(BuildContext context) {
    if (searchTerm.isEmpty) {
      return const Center(child: Text("Saisissez un terme pour rechercher"));
    }

    // Convertir le terme de recherche en minuscules
    String normalizedSearchTerm = searchTerm.toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('title', isGreaterThanOrEqualTo: normalizedSearchTerm)
          .where('title', isLessThanOrEqualTo: '$normalizedSearchTerm\uf7ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Aucun résultat trouvé"));
        }

        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            Map<String, dynamic> data = document.data() as Map<String, dynamic>;
            Post post;

            switch (data['type']) {
              case 'job_offer':
                post = JobOffer.fromDocument(document);
                break;
              case 'contest':
                post = Contest.fromDocument(document);
                break;
              case 'express_deal':
                post = ExpressDeal.fromDocument(document);
                break;
              case 'event':
                post = Event.fromDocument(document);
                break;
              case 'happy_deal':
                post = HappyDeal.fromDocument(document);
                break;
              case 'referral':
                post = Referral.fromDocument(document);
                break;
              default:
                return const SizedBox.shrink();
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('companys')
                  .doc(data['companyId'])
                  .snapshots(),
              builder: (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot> companySnapshot) {
                if (companySnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (companySnapshot.hasError) {
                  return const Text('Error loading company data');
                }
                if (!companySnapshot.hasData || !companySnapshot.data!.exists) {
                  return const Text('Company not found');
                }

                Map<String, dynamic>? companyData =
                    companySnapshot.data!.data() as Map<String, dynamic>?;

                if (companyData == null) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: PostWidget(
                    key: Key(document.id),
                    post: post,
                    companyCover: companyData['cover'],
                    companyCategorie: companyData['categorie'] ?? '',
                    companyName: companyData['name'] ?? 'Unknown',
                    companyLogo: companyData['logo'] ?? '',
                    currentUserId:
                        '', // Ajoutez l'ID de l'utilisateur actuel si nécessaire
                    onView: () {},
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
