import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/widgets/cards/emploi_card.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';

class JobOffersPage extends StatefulWidget {
  const JobOffersPage({super.key});

  @override
  _JobOffersPageState createState() => _JobOffersPageState();
}

class _JobOffersPageState extends State<JobOffersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedLocation = 'Tous';
  String _selectedSector = 'Tous';
  List<String> _locations = ['Tous'];
  List<String> _sectors = ['Tous'];

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final jobOffersSnapshot = await _firestore
          .collection('posts')
          .where('type', isEqualTo: 'job_offer')
          .get();

      Set<String> locationsSet = {'Tous'};
      Set<String> sectorsSet = {'Tous'};

      for (var doc in jobOffersSnapshot.docs) {
        final data = doc.data();
        if (data['city'] != null) locationsSet.add(data['city'] as String);
        if (data['industrySector'] != null) {
          sectorsSet.add(data['industrySector'] as String);
        }
      }

      setState(() {
        _locations = locationsSet.toList()..sort();
        _sectors = sectorsSet.toList()..sort();
      });
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarBack(
        title: 'Offres d\'emploi',
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          Expanded(
            child: _buildJobOffersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher une offre d\'emploi',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => _searchController.clear(),
          ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() {}); // Trigger a rebuild when search text changes
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              'Lieu',
              _selectedLocation,
              _locations,
              (value) => setState(() => _selectedLocation = value!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterDropdown(
              'Secteur',
              _selectedSector,
              _sectors,
              (value) => setState(() => _selectedSector = value!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String hint,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint),
          value: value == 'Tous' ? null : value,
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildJobOffersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('type', isEqualTo: 'job_offer')
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
          return const Center(child: Text('Aucune offre d\'emploi disponible'));
        }

        final jobOffers = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView.builder(
            itemCount: jobOffers.length,
            itemBuilder: (context, index) {
              final jobOfferData =
                  jobOffers[index].data() as Map<String, dynamic>;

              if (!_matchesFilters(jobOfferData)) {
                return const SizedBox.shrink();
              }

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('companys')
                    .doc(jobOfferData['companyId'])
                    .get(),
                builder: (context, companySnapshot) {
                  if (companySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final companyData =
                      companySnapshot.data?.data() as Map<String, dynamic>?;
                  final companyName = companyData?['name'] ?? 'Nom inconnu';
                  final companyLogo = companyData?['logo'] ?? '';

                  return JobOfferCard(
                    post: JobOffer.fromDocument(jobOffers[index]),
                    companyName: companyName,
                    companyLogo: companyLogo,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  bool _matchesFilters(Map<String, dynamic> jobOfferData) {
    final searchText = _searchController.text.toLowerCase();
    if (searchText.isNotEmpty &&
        !jobOfferData['title'].toString().toLowerCase().contains(searchText) &&
        !jobOfferData['description']
            .toString()
            .toLowerCase()
            .contains(searchText)) {
      return false;
    }

    if (_selectedLocation != 'Tous' &&
        jobOfferData['city'] != _selectedLocation) {
      return false;
    }

    if (_selectedSector != 'Tous' &&
        jobOfferData['industrySector'] != _selectedSector) {
      return false;
    }

    return true;
  }
}
