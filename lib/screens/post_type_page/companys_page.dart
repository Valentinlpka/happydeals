import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/widgets/cards/company_card.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  _CompaniesPageState createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
        title: const Text('Entreprises'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildCompaniesList(),
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

        final companies = snapshot.data!.docs;

        return ListView.builder(
          itemCount: companies.length,
          itemBuilder: (context, index) {
            final company = Company.fromDocument(companies[index]);

            if (_selectedCategory != 'Toutes' &&
                company.categorie != _selectedCategory) {
              return const SizedBox.shrink();
            }

            return CompanyCard(company);
          },
        );
      },
    );
  }
}
