import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/utils/location_utils.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/location_filter.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/search_bar.dart';

class JeuxConcoursPage extends StatefulWidget {
  const JeuxConcoursPage({super.key});

  @override
  State<JeuxConcoursPage> createState() => _JeuxConcoursPageState();
}

class _JeuxConcoursPageState extends State<JeuxConcoursPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Toutes';
  List<String> _categories = ['Toutes'];
  double? _selectedLat;
  double? _selectedLng;
  double _selectedRadius = 5.0;
  String _selectedAddress = '';

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
        align: Alignment.center,
        title: 'Jeux Concours',
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
          _buildSearchBar(),
          _buildContestList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return CustomSearchBar(
      controller: _searchController,
      hintText: 'Rechercher un concours...',
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      onClear: () {
        setState(() {
          _searchQuery = '';
        });
      },
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
                            _selectedCategory = 'Toutes';
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Catégories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return FilterChip(
                        selected: isSelected,
                        label: Text(category),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[800],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: Colors.grey[200],
                        selectedColor: const Color(0xFF4B88DA),
                        onSelected: (bool selected) {
                          setModalState(() {
                            _selectedCategory = category;
                          });
                        },
                        showCheckmark: false,
                      );
                    }).toList(),
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

  Widget _buildContestList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('type', isEqualTo: 'contest')
          .where('isActive', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Expanded(
            child: Center(child: Text('Aucun concours disponible')),
          );
        }

        final contests = snapshot.data!.docs;

        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(5),
            itemCount: contests.length,
            itemBuilder: (context, index) {
              final contest = Contest.fromDocument(contests[index]);

              if (_searchQuery.isNotEmpty &&
                  !contest.title
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase())) {
                return const SizedBox.shrink();
              }

              if (contest.companyAddress != null) {
                final companyLat = double.tryParse(contest.companyAddress!['latitude'].toString()) ?? 0.0;
                final companyLng = double.tryParse(contest.companyAddress!['longitude'].toString()) ?? 0.0;
                final companyCategorie = contest.companyAddress!['category'] as String? ?? '';

                if (_selectedCategory != 'Toutes' &&
                    companyCategorie != _selectedCategory) {
                  return const SizedBox.shrink();
                }

                if (_selectedLat != null &&
                    _selectedLng != null &&
                    !LocationUtils.isWithinRadius(
                      _selectedLat!,
                      _selectedLng!,
                      companyLat,
                      companyLng,
                      _selectedRadius,
                    )) {
                  return const SizedBox.shrink();
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: PostWidget(
                  post: contest,
                  onView: () {},
                  currentProfileUserId: currentUserId,
                  currentUserId: currentUserId,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
