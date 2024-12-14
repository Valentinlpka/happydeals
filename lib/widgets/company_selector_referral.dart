import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/referral_options_modal.dart';

class CompanyReferralButton extends StatelessWidget {
  const CompanyReferralButton({super.key});

  void _showCompanySelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const CompanySelectionSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.people_outline, color: Colors.white),
          label: const Text(
            'Parrainer une entreprise',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => _showCompanySelectionSheet(context),
        ),
      ),
    );
  }
}

class CompanySelectionSheet extends StatefulWidget {
  const CompanySelectionSheet({super.key});

  @override
  State<CompanySelectionSheet> createState() => _CompanySelectionSheetState();
}

class _CompanySelectionSheetState extends State<CompanySelectionSheet> {
  late Future<List<Company>> companiesFuture;
  TextEditingController searchController = TextEditingController();
  List<Company> filteredCompanies = [];
  List<Company> allCompanies = [];

  @override
  void initState() {
    super.initState();
    companiesFuture = _fetchCompanies();
  }

  Future<List<Company>> _fetchCompanies() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('companys')
        .orderBy('name')
        .get();

    return querySnapshot.docs.map((doc) => Company.fromDocument(doc)).toList();
  }

  void _filterCompanies(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredCompanies = List.from(allCompanies);
      } else {
        filteredCompanies = allCompanies
            .where((company) =>
                company.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showReferralOptionsModal(Company company) {
    Navigator.pop(context); // Ferme le bottom sheet de sélection d'entreprise
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ReferralOptionsModal(
              companyId: company.id,
              referralId: '',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Barre de titre avec poignée de drag
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Poignée de drag
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sélectionner une entreprise',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: _filterCompanies,
              decoration: InputDecoration(
                hintText: 'Rechercher une entreprise...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ),
          // Liste des entreprises
          Expanded(
            child: FutureBuilder<List<Company>>(
              future: companiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur: ${snapshot.error}'),
                  );
                }

                if (allCompanies.isEmpty && snapshot.hasData) {
                  allCompanies = snapshot.data!;
                  filteredCompanies = List.from(allCompanies);
                }

                return ListView.builder(
                  itemCount: filteredCompanies.length,
                  itemBuilder: (context, index) {
                    final company = filteredCompanies[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(company.logo),
                      ),
                      title: Text(company.name),
                      subtitle: Text(company.categorie),
                      onTap: () => _showReferralOptionsModal(company),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
