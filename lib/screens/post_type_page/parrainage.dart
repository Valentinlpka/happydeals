import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/utils/location_utils.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/current_location_display.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/unified_location_filter.dart';
import 'package:provider/provider.dart';

class ParraiangePage extends StatefulWidget {
  const ParraiangePage({super.key});

  @override
  State<ParraiangePage> createState() => _ParraiangePageState();
}

class _ParraiangePageState extends State<ParraiangePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _searchQuery = '';
  String _selectedCategory = 'Toutes';
  List<String> _categories = ['Toutes'];
  // Variables pour la localisation (maintenant gérées par LocationProvider)

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    await locationProvider.initializeLocation(userModel);
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
    await UnifiedLocationFilter.show(
      context: context,
      onLocationChanged: () {
        setState(() {
          // La localisation a été mise à jour via le provider
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, UserModel>(
      builder: (context, locationProvider, userModel, child) {
        return Scaffold(
          appBar: CustomAppBar(
            align: Alignment.center,
            title: 'Parrainage',
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.location_on,
                      color: locationProvider.hasLocation 
                          ? const Color(0xFF4B88DA) 
                          : null,
                    ),
                    onPressed: _showLocationFilterBottomSheet,
                  ),
                  if (locationProvider.hasLocation)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4B88DA),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterBottomSheet,
              ),
            ],
          ),
          body: Column(
            children: [
              CurrentLocationDisplay(
                onLocationChanged: () {
                  setState(() {
                    // La localisation a été mise à jour
                  });
                },
              ),
              _buildSearchBar(),
              _buildReferralList(locationProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Container(
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
            hintText: 'Rechercher un parrainage...',
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

  Widget _buildReferralList(LocationProvider locationProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('type', isEqualTo: 'referral')
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
            child: Center(child: Text('Aucun parrainage disponible')),
          );
        }

        final referrals = snapshot.data!.docs;

        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(5.0),
            itemCount: referrals.length,
            itemBuilder: (context, index) {
              final referral = Referral.fromDocument(referrals[index]);

              if (_searchQuery.isNotEmpty &&
                  !referral.title
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase())) {
                return const SizedBox.shrink();
              }

              final companyAddress = referral.companyAddress;
              final companyLat = double.tryParse(companyAddress['latitude'].toString()) ?? 0.0;
              final companyLng = double.tryParse(companyAddress['longitude'].toString()) ?? 0.0;
              final companyCategorie = companyAddress['category'] as String? ?? '';

              if (_selectedCategory != 'Toutes' &&
                  companyCategorie != _selectedCategory) {
                return const SizedBox.shrink();
              }

              if (locationProvider.hasLocation &&
                  !LocationUtils.isWithinRadius(
                    locationProvider.latitude!,
                    locationProvider.longitude!,
                    companyLat,
                    companyLng,
                    locationProvider.radius,
                  )) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: PostWidget(
                  post: referral,
                  currentUserId: currentUserId,
                  currentProfileUserId: currentUserId,
                  onView: () {},
                ),
              );
            },
          ),
        );
      },
    );
  }
}
