import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/custom_app_bar.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  _CompaniesPageState createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedCategory = 'Toutes';
  String _selectedCity = 'Toutes';
  List<String> _categories = ['Toutes'];
  List<String> _cities = ['Toutes'];

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final companiesSnapshot = await _firestore.collection('companys').get();
    final categories = companiesSnapshot.docs
        .map((doc) => doc['categorie'] as String)
        .toSet()
        .toList();
    final cities = companiesSnapshot.docs
        .map((doc) => doc['adress']['ville'] as String)
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _categories = ['Toutes', ...categories];
      _cities = ['Toutes', ...cities];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: CustomAppBar(
          title: 'Entreprises',
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
            _buildCompaniesList(),
          ],
        ));
  }

  Widget _buildSearchBar() {
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
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une entreprise...',
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
          if (_selectedCategory != 'Toutes' || _selectedCity != 'Toutes')
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedCategory != 'Toutes')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_selectedCategory),
                        onSelected: (_) {}, // Ajout du paramètre requis
                        onDeleted: () {
                          setState(() {
                            _selectedCategory = 'Toutes';
                          });
                        },
                        selected: true,
                        deleteIcon: const Icon(Icons.close,
                            size: 18, color: Colors.white),
                        backgroundColor: const Color(0xFF4B88DA),
                        selectedColor: const Color(0xFF4B88DA),
                        labelStyle: const TextStyle(color: Colors.white),
                        showCheckmark: false,
                      ),
                    ),
                  if (_selectedCity != 'Toutes')
                    FilterChip(
                      label: Text(_selectedCity),
                      onSelected: (_) {}, // Ajout du paramètre requis
                      onDeleted: () {
                        setState(() {
                          _selectedCity = 'Toutes';
                        });
                      },
                      selected: true,
                      deleteIcon: const Icon(Icons.close,
                          size: 18, color: Colors.white),
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
              focusColor: Colors.transparent,
              isExpanded: true,
              value: value,
              onChanged: onChanged,
              items: items.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              icon: const Icon(Icons.arrow_drop_down),
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              dropdownColor: Colors.white,
              // Ajoutez cette propriété pour personnaliser l'apparence de l'élément sélectionné
              selectedItemBuilder: (BuildContext context) {
                return items.map<Widget>((String item) {
                  return Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ],
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
                            _selectedCity = 'Toutes';
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFilterDropdown(
                    'Catégorie',
                    _selectedCategory,
                    _categories,
                    (String? newValue) {
                      if (newValue != null) {
                        setModalState(() {
                          _selectedCategory = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFilterDropdown(
                    'Ville',
                    _selectedCity,
                    _cities,
                    (String? newValue) {
                      if (newValue != null) {
                        setModalState(() {
                          _selectedCity = newValue;
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

  Widget _buildCompaniesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('companys').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucune entreprise disponible'));
        }

        final companies = snapshot.data!.docs
            .map((doc) => Company.fromDocument(doc))
            .where((company) =>
                (_selectedCategory == 'Toutes' ||
                    company.categorie == _selectedCategory) &&
                (_selectedCity == 'Toutes' ||
                    company.adress.ville == _selectedCity) &&
                company.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

        if (companies.isEmpty) {
          return const Center(child: Text('Aucune entreprise trouvée'));
        }

        return Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20.0),
            itemCount: companies.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: CompanyCard(companies[index]),
              );
            },
          ),
        );
      },
    );
  }
}
