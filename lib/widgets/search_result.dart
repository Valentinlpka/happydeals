import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart'; // Assurez-vous d'importer la classe Company
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/postwidget.dart';

class SearchResults extends StatelessWidget {
  final String searchTerm;

  const SearchResults({super.key, required this.searchTerm});

  @override
  Widget build(BuildContext context) {
    if (searchTerm.isEmpty) {
      return const Center(child: Text("Saisissez un terme pour rechercher"));
    }

    String normalizedSearchTerm = normalizeText(searchTerm);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('searchText', isGreaterThanOrEqualTo: normalizedSearchTerm)
          .where('searchText',
              isLessThanOrEqualTo: '$normalizedSearchTerm\uf7ff')
          .snapshots(),
      builder: (context, postSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('companys')
              .where('searchText', isGreaterThanOrEqualTo: normalizedSearchTerm)
              .where('searchText',
                  isLessThanOrEqualTo: '$normalizedSearchTerm\uf7ff')
              .snapshots(),
          builder: (context, companySnapshot) {
            if (postSnapshot.connectionState == ConnectionState.waiting ||
                companySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            List<Widget> results = [];

            // Ajouter les résultats des posts
            if (postSnapshot.hasData) {
              results.addAll(postSnapshot.data!.docs
                  .map((document) => buildPostWidget(document)));
            }

            // Ajouter les résultats des entreprises
            if (companySnapshot.hasData) {
              results.addAll(companySnapshot.data!.docs
                  .map((document) => buildCompanyCard(document)));
            }

            if (results.isEmpty) {
              return const Center(child: Text("Aucun résultat trouvé"));
            }

            return ListView(children: results);
          },
        );
      },
    );
  }

  Widget buildPostWidget(DocumentSnapshot document) {
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
        if (companySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (companySnapshot.hasError ||
            !companySnapshot.hasData ||
            !companySnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        Map<String, dynamic> companyData =
            companySnapshot.data!.data() as Map<String, dynamic>;

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
  }

  Widget buildCompanyCard(DocumentSnapshot document) {
    Company company = Company.fromDocument(document);
    return CompanyCard(company);
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
