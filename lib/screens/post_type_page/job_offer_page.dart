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
  List<String> _locations = ['Tous'];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final locationsSnapshot = await _firestore
        .collection('posts')
        .where('type', isEqualTo: 'job_offer')
        .get();

    final locations = locationsSnapshot.docs
        .map((doc) => doc['city'] as String)
        .toSet()
        .toList();

    setState(() {
      _locations = ['Tous', ...locations];
    });
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButton<String>(
        value: _selectedLocation,
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedLocation = newValue;
            });
          }
        },
        items: _locations.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
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
          print(snapshot.error);
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

            if (_selectedLocation != 'Tous' &&
                jobOfferData['city'] != _selectedLocation) {
              return const SizedBox.shrink();
            }

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore
                  .collection('companies')
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
}
