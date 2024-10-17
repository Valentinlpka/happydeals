import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/postwidget.dart';

class SearchResults extends StatelessWidget {
  final String searchTerm;
  final String filter;

  const SearchResults(
      {super.key, required this.searchTerm, required this.filter});

  @override
  Widget build(BuildContext context) {
    if (searchTerm.isEmpty) {
      return const Center(child: Text("Saisissez un terme pour rechercher"));
    }

    String normalizedSearchTerm = normalizeText(searchTerm);

    return FutureBuilder<List<Widget>>(
      future: _getFilteredResults(context, normalizedSearchTerm),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Erreur: ${snapshot.error}"));
        }

        List<Widget> results = snapshot.data ?? [];

        if (results.isEmpty) {
          return const Center(child: Text("Aucun résultat trouvé"));
        }

        return ListView(children: results);
      },
    );
  }

  Future<List<Widget>> _getFilteredResults(
      BuildContext context, String normalizedSearchTerm) async {
    List<Widget> results = [];

    if (filter == "Tous" || filter == "Utilisateurs") {
      results.addAll(await _getUserResults(context, normalizedSearchTerm));
    }

    if (filter == "Tous" || filter == "Entreprises") {
      results.addAll(await _getCompanyResults(normalizedSearchTerm));
    }

    if (filter == "Tous" || filter == "Posts") {
      results.addAll(await _getPostResults(normalizedSearchTerm));
    }

    return results;
  }

  Future<List<Widget>> _getUserResults(
      BuildContext context, String normalizedSearchTerm) async {
    QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('searchName', arrayContains: normalizedSearchTerm)
        .get();

    return userSnapshot.docs
        .map((doc) => buildUserWidget(context, doc))
        .toList();
  }

  Future<List<Widget>> _getCompanyResults(String normalizedSearchTerm) async {
    QuerySnapshot companySnapshot = await FirebaseFirestore.instance
        .collection('companys')
        .where('searchText', isGreaterThanOrEqualTo: normalizedSearchTerm)
        .where('searchText', isLessThanOrEqualTo: '$normalizedSearchTerm\uf7ff')
        .get();

    return companySnapshot.docs.map((doc) => buildCompanyCard(doc)).toList();
  }

  Future<List<Widget>> _getPostResults(String normalizedSearchTerm) async {
    QuerySnapshot postSnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('searchText', isGreaterThanOrEqualTo: normalizedSearchTerm)
        .where('searchText', isLessThanOrEqualTo: '$normalizedSearchTerm\uf7ff')
        .get();

    List<Widget> postWidgets = [];
    for (var doc in postSnapshot.docs) {
      Widget postWidget = await buildPostWidget(doc);
      postWidgets.add(postWidget);
    }

    return postWidgets;
  }

  Widget buildUserWidget(BuildContext context, DocumentSnapshot document) {
    Map<String, dynamic> userData = document.data() as Map<String, dynamic>;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(userData['image_profile'] ?? ''),
      ),
      title: Text('${userData['firstName']} ${userData['lastName']}'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Profile(userId: document.id),
          ),
        );
      },
    );
  }

  Widget buildCompanyCard(DocumentSnapshot document) {
    Company company = Company.fromDocument(document);
    return CompanyCard(company);
  }

  Future<Widget> buildPostWidget(DocumentSnapshot document) async {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    Post post = Post.fromDocument(document);

    DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
        .collection('companys')
        .doc(data['companyId'])
        .get();

    if (!companySnapshot.exists) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic> companyData =
        companySnapshot.data() as Map<String, dynamic>;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: PostWidget(
        key: Key(document.id),
        post: post,
        companyCover: companyData['cover'],
        companyCategorie: companyData['categorie'] ?? '',
        companyName: companyData['name'] ?? 'Unknown',
        companyLogo: companyData['logo'] ?? '',
        companyData: companyData,
        currentUserId: '',
        currentProfileUserId: '',
        onView: () {},
      ),
    );
  }

  String normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }
}
