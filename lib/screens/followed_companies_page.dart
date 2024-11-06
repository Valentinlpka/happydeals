import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class FollowedCompaniesPage extends StatelessWidget {
  const FollowedCompaniesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModel>(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Entreprises suivies',
        align: Alignment.center,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('companys')
            .where(FieldPath.documentId, whereIn: userModel.likedCompanies)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vous ne suivez aucune entreprise',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explorez notre catalogue d\'entreprises\npour en découvrir de nouvelles',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Navigation vers le catalogue d'entreprises
                      Navigator.of(context).pushNamed('/companies');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Explorer les entreprises',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final company = Company.fromDocument(doc);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CompanyCard(company),
              );
            },
          );
        },
      ),
    );
  }
}
