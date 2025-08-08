import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/current_location_display.dart';
import 'package:happy/widgets/unified_location_filter.dart';
import 'package:provider/provider.dart';

class CompaniesPageUnified extends StatefulWidget {
  const CompaniesPageUnified({super.key});

  @override
  State<CompaniesPageUnified> createState() => _CompaniesPageUnifiedState();
}

class _CompaniesPageUnifiedState extends State<CompaniesPageUnified> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedCategory = 'Toutes';
  List<String> _categories = ['Toutes'];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final companiesSnapshot = await _firestore.collection('companys').get();
      final Set<String> categories = {};

      for (var doc in companiesSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('categorie')) {
          categories.add(data['categorie'] as String);
        }
      }

      setState(() {
        _categories = ['Toutes', ...categories];
      });
    } catch (e) {
      setState(() {
        _categories = ['Toutes'];
      });
    }
  }

  Future<void> _initializeLocation() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    await locationProvider.initializeLocation(userModel);
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
            title: 'Entreprises',
            align: Alignment.center,
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
              Expanded(
                child: _buildContent(locationProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'Rechercher une entreprise...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  Widget _buildContent(LocationProvider locationProvider) {
    if (locationProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (locationProvider.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erreur de localisation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              locationProvider.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeLocation,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return _buildCompaniesList(locationProvider);
  }

  Widget _buildCompaniesList(LocationProvider locationProvider) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('companys').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final companies = snapshot.data?.docs.map((doc) {
          return Company.fromDocument(doc);
        }).toList() ?? [];

        // Filtrer par catégorie
        final filteredCompanies = _selectedCategory == 'Toutes'
            ? companies
            : companies.where((company) => company.categorie == _selectedCategory).toList();

        // Filtrer par recherche
        final searchedCompanies = _searchController.text.isEmpty
            ? filteredCompanies
            : filteredCompanies.where((company) =>
                company.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                company.description.toLowerCase().contains(_searchController.text.toLowerCase())
              ).toList();

        // Filtrer par localisation si disponible
        final locationFilteredCompanies = locationProvider.hasLocation
            ? searchedCompanies.where((company) {
                if (company.adress.latitude == null || company.adress.longitude == null) return false;
                return locationProvider.isWithinRadius(
                  company.adress.latitude!,
                  company.adress.longitude!,
                );
              }).toList()
            : searchedCompanies;

        if (locationFilteredCompanies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  locationProvider.hasLocation 
                      ? 'Aucune entreprise trouvée dans votre zone'
                      : 'Aucune entreprise trouvée',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                if (locationProvider.hasLocation) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rayon de recherche: ${locationProvider.radius.round()} km',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: locationFilteredCompanies.length,
          itemBuilder: (context, index) {
            final company = locationFilteredCompanies[index];
            return CompanyCard(company);
          },
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filtrer par catégorie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return ListTile(
                    title: Text(category),
                    trailing: _selectedCategory == category
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 