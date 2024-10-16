import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';

class ParraiangePage extends StatefulWidget {
  const ParraiangePage({super.key});

  @override
  _ParraiangePageState createState() => _ParraiangePageState();
}

class _ParraiangePageState extends State<ParraiangePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _selectedCategory = 'Toutes';
  List<String> _categories = ['Toutes'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categoriesSnapshot = await _firestore.collection('companys').get();

    final categories = categoriesSnapshot.docs
        .map((doc) => doc['categorie'] as String)
        .toSet()
        .toList();

    setState(() {
      _categories = ['Toutes', ...categories];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Happy Deals'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildHappyDealsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButton<String>(
        value: _selectedCategory,
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedCategory = newValue;
            });
          }
        },
        items: _categories.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHappyDealsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('type', isEqualTo: 'referral')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print(snapshot.error);
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun Happy Deal disponible'));
        }

        final happyDeals = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView.builder(
            itemCount: happyDeals.length,
            itemBuilder: (context, index) {
              final happyDeal = Referral.fromDocument(happyDeals[index]);

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('companys')
                    .doc(happyDeal.companyId)
                    .get(),
                builder: (context, companySnapshot) {
                  if (companySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }

                  if (companySnapshot.hasError || !companySnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final companyData =
                      companySnapshot.data!.data() as Map<String, dynamic>;
                  final companyName = companyData['name'] as String;
                  final companyCategorie = companyData['categorie'] as String;
                  final companyLogo = companyData['logo'] as String;

                  if (_selectedCategory != 'Toutes' &&
                      companyCategorie != _selectedCategory) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ParrainageCard(
                      post: happyDeal,
                      companyName: companyName,
                      companyLogo: companyLogo,
                      currentUserId: currentUserId,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
