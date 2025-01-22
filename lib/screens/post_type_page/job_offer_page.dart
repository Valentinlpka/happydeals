import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/widgets/cards/emploi_card.dart';
import 'package:happy/widgets/custom_app_bar.dart';

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
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Offres d\'emploi',
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
          _buildSearchAndFilters(),
          Expanded(
            child: _buildJobOffersList(),
          ),
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
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une offre d\'emploi...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),

          // Filtres sélectionnés
          if (_selectedLocation != 'Tous' || _selectedSector != 'Tous')
            Container(
              margin: const EdgeInsets.only(top: 12),
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedLocation != 'Tous')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_selectedLocation),
                        onSelected: (_) {},
                        selected: true,
                        onDeleted: () {
                          setState(() {
                            _selectedLocation = 'Tous';
                          });
                        },
                        deleteIcon: const Icon(Icons.close,
                            size: 18, color: Colors.white),
                        backgroundColor: const Color(0xFF4B88DA),
                        selectedColor: const Color(0xFF4B88DA),
                        labelStyle: const TextStyle(color: Colors.white),
                        showCheckmark: false,
                      ),
                    ),
                  if (_selectedSector != 'Tous')
                    FilterChip(
                      label: Text(_selectedSector),
                      onSelected: (_) {},
                      selected: true,
                      onDeleted: () {
                        setState(() {
                          _selectedSector = 'Tous';
                        });
                      },
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
                            _selectedLocation = 'Tous';
                            _selectedSector = 'Tous';
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFilterDropdown(
                    'Lieu',
                    _selectedLocation,
                    _locations,
                    (String? newValue) {
                      if (newValue != null) {
                        setModalState(() {
                          _selectedLocation = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFilterDropdown(
                    'Secteur',
                    _selectedSector,
                    _sectors,
                    (String? newValue) {
                      if (newValue != null) {
                        setModalState(() {
                          _selectedSector = newValue;
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
          return const Center(child: Text('Aucune offre d\'emploi disponible'));
        }

        final jobOffers = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.all(5.0),
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
