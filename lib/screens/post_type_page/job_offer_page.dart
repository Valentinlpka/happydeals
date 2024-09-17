import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/widgets/cards/emploi_card.dart';

class JobOffersPage extends StatefulWidget {
  const JobOffersPage({super.key});

  @override
  _JobOffersPageState createState() => _JobOffersPageState();
}

class _JobOffersPageState extends State<JobOffersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedLocation = 'Tous';
  String _selectedSector = 'Tous';
  String _selectedDate = 'Tous';
  List<String> _locations = ['Tous'];
  List<String> _sectors = ['Tous'];
  final List<String> _dates = [
    'Tous',
    'Aujourd\'hui',
    'Cette semaine',
    'Ce mois-ci'
  ];

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

      print("Nombre total de documents: ${jobOffersSnapshot.docs.length}");

      Set<String> locationsSet = {};
      Set<String> sectorsSet = {};

      for (var doc in jobOffersSnapshot.docs) {
        final data = doc.data();
        print("Document data: $data"); // Debugging: print each document's data

        if (data.containsKey('city') && data['city'] != null) {
          locationsSet.add(data['city'] as String);
        }
        if (data.containsKey('sector') && data['sector'] != null) {
          sectorsSet.add(data['sector'] as String);
        }
      }

      print("Locations trouvées: $locationsSet");
      print("Secteurs trouvés: $sectorsSet");

      setState(() {
        _locations = ['Tous', ...locationsSet];
        _sectors = ['Tous', ...sectorsSet];
      });
    } catch (e) {
      print("Erreur lors du chargement des filtres: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offres d\'emploi'),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildJobOffersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtres',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildDropdown('Ville', _selectedLocation, _locations,
                      (value) => _selectedLocation = value)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildDropdown('Secteur', _selectedSector, _sectors,
                      (value) => _selectedSector = value)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildDropdown('Date', _selectedDate, _dates,
                      (value) => _selectedDate = value)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items,
      Function(String) onChanged) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: value,
      onChanged: (newValue) {
        if (newValue != null) {
          setState(() {
            onChanged(newValue);
          });
        }
      },
      items: items.map<DropdownMenuItem<String>>((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, style: const TextStyle(fontSize: 14)),
        );
      }).toList(),
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

        return ListView.builder(
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
        );
      },
    );
  }

  bool _matchesFilters(Map<String, dynamic> jobOfferData) {
    if (_selectedLocation != 'Tous' &&
        jobOfferData['city'] != _selectedLocation) {
      return false;
    }

    if (_selectedSector != 'Tous' &&
        jobOfferData['sector'] != _selectedSector) {
      return false;
    }

    if (_selectedDate != 'Tous') {
      final publishDate = (jobOfferData['timestamp'] as Timestamp).toDate();
      final now = DateTime.now();

      switch (_selectedDate) {
        case 'Aujourd\'hui':
          if (!DateUtils.isSameDay(publishDate, now)) return false;
          break;
        case 'Cette semaine':
          final weekAgo = now.subtract(const Duration(days: 7));
          if (publishDate.isBefore(weekAgo)) return false;
          break;
        case 'Ce mois-ci':
          if (publishDate.month != now.month || publishDate.year != now.year) {
            return false;
          }
          break;
      }
    }

    return true;
  }
}
