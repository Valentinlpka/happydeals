import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/utils/location_utils.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/location_filter.dart';
import 'package:happy/widgets/postwidget.dart';

import '../../classes/promo_code_post.dart';

class CodePromoPage extends StatefulWidget {
  const CodePromoPage({super.key});

  @override
  State<CodePromoPage> createState() => _CodePromoPageState();
}

class _CodePromoPageState extends State<CodePromoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedCompany = 'Toutes';
  List<String> _companies = ['Toutes'];
  double? _selectedLat;
  double? _selectedLng;
  double _selectedRadius = 5.0;
  String _selectedAddress = '';

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

  void _showLocationFilterBottomSheet() async {
    await LocationFilterBottomSheet.show(
      context: context,
      onLocationSelected: (lat, lng, radius, address) {
        setState(() {
          _selectedLat = lat;
          _selectedLng = lng;
          _selectedRadius = radius;
          _selectedAddress = address;
        });
      },
      currentLat: _selectedLat,
      currentLng: _selectedLng,
      currentRadius: _selectedRadius,
      currentAddress: _selectedAddress,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Code Promo',
        align: Alignment.center,
        actions: [
          IconButton(
            icon: Icon(
              Icons.location_on,
              color: _selectedLat != null ? const Color(0xFF4B88DA) : null,
            ),
            onPressed: _showLocationFilterBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildPromoCodesList(),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Barre de recherche moderne
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un code promo...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filtres sélectionnés
          if (_selectedCompany != 'Toutes')
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FilterChip(
                    label: Text(_selectedCompany),
                    onSelected: (_) {},
                    selected: true,
                    onDeleted: () {
                      setState(() {
                        _selectedCompany = 'Toutes';
                      });
                    },
                    deleteIcon:
                        const Icon(Icons.close, size: 18, color: Colors.white),
                    backgroundColor: const Color(0xFF4B88DA),
                    selectedColor: const Color(0xFF4B88DA),
                    labelStyle: const TextStyle(color: Colors.white),
                    showCheckmark: false,
                  ),
                ],
              ),
            ),
        ],
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
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtres',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCompany = 'Toutes';
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B88DA),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Appliquer les filtres',
                      style: TextStyle(fontSize: 16),
                    ),
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
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint(snapshot.error.toString());
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun code promo disponible'));
        }

        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(5.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final postDoc = snapshot.data!.docs[index];
              final promoCodePost = PromoCodePost.fromDocument(postDoc);

              if (!promoCodePost.isUsable) {
                return const SizedBox.shrink();
              }

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

                  // Filtrer par entreprise
                  if (_selectedCompany != 'Toutes' &&
                      companyData['name'] != _selectedCompany) {
                    return const SizedBox.shrink();
                  }

                  // Filtrer par recherche
                  if (_searchQuery.isNotEmpty &&
                      !promoCodePost.code
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) &&
                      !promoCodePost.description
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase())) {
                    return const SizedBox.shrink();
                  }

                  // Filtrer par localisation
                  if (_selectedLat != null &&
                      _selectedLng != null &&
                      !LocationUtils.isWithinRadius(
                        _selectedLat!,
                        _selectedLng!,
                        companyData['adress']['latitude'],
                        companyData['adress']['longitude'],
                        _selectedRadius,
                      )) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: PostWidget(
                      post: promoCodePost,
                      currentUserId: '',
                      currentProfileUserId: '',
                      onView: () {},
                      companyData: CompanyData(
                        name: companyData['name'],
                        category: companyData['categorie'] ?? '',
                        logo: companyData['logo'],
                        cover: companyData['cover'] ?? '',
                        rawData: companyData,
                      ),
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
