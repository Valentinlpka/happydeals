import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/widgets/cards/deals_express_card.dart';

class DealExpressPage extends StatefulWidget {
  const DealExpressPage({super.key});

  @override
  _DealExpressPageState createState() => _DealExpressPageState();
}

class _DealExpressPageState extends State<DealExpressPage> {
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
        title: const Text('Deal Express'),
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
          .where('type', isEqualTo: 'express_deal')
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

        return ListView.builder(
          itemCount: happyDeals.length,
          itemBuilder: (context, index) {
            final happyDeal = ExpressDeal.fromDocument(happyDeals[index]);

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

                return DealsExpressCard(
                  post: happyDeal,
                  companyName: companyName,
                  companyLogo: companyLogo,
                  currentUserId: currentUserId,
                );
              },
            );
          },
        );
      },
    );
  }
}
