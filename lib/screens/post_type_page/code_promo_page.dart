import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/promo_codes.dart';
import 'package:happy/widgets/custom_app_bar.dart';

import '../../classes/promo_code_post.dart';

class CodePromoPage extends StatefulWidget {
  const CodePromoPage({super.key});

  @override
  _CodePromoPageState createState() => _CodePromoPageState();
}

class _CodePromoPageState extends State<CodePromoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedCompany = 'Toutes';
  List<String> _companies = ['Toutes'];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    final companiesSnapshot = await _firestore.collection('companys').get();
    final companies = companiesSnapshot.docs
        .map((doc) => doc['name'] as String)
        .toSet()
        .toList();

    setState(() {
      _companies = ['Toutes', ...companies];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Code Promo',
        align: Alignment.center,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildPromoCodesList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, left: 20, right: 20),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher un code promo...',
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtres',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildFilterDropdown(
                    'Entreprise',
                    _selectedCompany,
                    _companies,
                    (String? newValue) {
                      if (newValue != null) {
                        setModalState(() {
                          _selectedCompany = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text('Appliquer les filtres'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPromoCodesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('type', isEqualTo: 'promo_code')
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
          return const Center(child: Text('Aucun code promo disponible'));
        }

        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final postDoc = snapshot.data!.docs[index];
              final promoCodePost = PromoCodePost.fromDocument(postDoc);

              // Ne montrer que les codes promo actifs et non expirés
              if (!promoCodePost.isUsable) {
                return const SizedBox.shrink();
              }

              // Fetch company data
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('companys')
                    .doc(promoCodePost.companyId)
                    .get(),
                builder: (context, companySnapshot) {
                  if (!companySnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final companyData =
                      companySnapshot.data!.data() as Map<String, dynamic>;

                  // Apply filters
                  if (_selectedCompany != 'Toutes' &&
                      companyData['name'] != _selectedCompany) {
                    return const SizedBox.shrink();
                  }

                  if (_searchQuery.isNotEmpty &&
                      !promoCodePost.code
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) &&
                      !promoCodePost.description
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase())) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: PromoCodeCard(
                      post: promoCodePost,
                      companyName: companyData['name'] ?? '',
                      companyLogo: companyData['logo'] ?? '',
                      currentUserId:
                          '', // Vous pouvez passer l'ID de l'utilisateur courant ici si nécessaire
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

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              onChanged: onChanged,
              items: items.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
