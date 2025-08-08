import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/utils/location_utils.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/current_location_display.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/search_bar.dart';
import 'package:happy/widgets/unified_location_filter.dart';
import 'package:provider/provider.dart';

class JobOffersPage extends StatefulWidget {
  const JobOffersPage({super.key});

  @override
  State<JobOffersPage> createState() => _JobOffersPageState();
}

class _JobOffersPageState extends State<JobOffersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedLocation = 'Tous';
  String _selectedSector = 'Tous';
  List<String> _locations = ['Tous'];
  List<String> _sectors = ['Tous'];

  // Variables pour la localisation (maintenant gérées par LocationProvider)

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    await locationProvider.initializeLocation(userModel);
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
      debugPrint(e.toString());
    }
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
            title: 'Offres d\'emploi',
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
              _buildSearchAndFilters(locationProvider),
              Expanded(
                child: _buildJobOffersList(locationProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilters(LocationProvider locationProvider) {
    return Column(
      children: [
        CustomSearchBar(
          controller: _searchController,
          hintText: 'Rechercher une offre d\'emploi...',
          onChanged: (value) {
            setState(() {});
          },
          onClear: () {
            setState(() {});
          },
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

  Widget _buildJobOffersList(LocationProvider locationProvider) {
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
                  if (!companySnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final companyData =
                      companySnapshot.data?.data() as Map<String, dynamic>?;

                  if (companyData == null) {
                    return const SizedBox.shrink();
                  }

                  final companyAddress =
                      companyData['adress'] as Map<String, dynamic>?;

                  // Vérification de la distance si un filtre de localisation est actif
                  if (locationProvider.hasLocation &&
                      companyAddress != null &&
                      companyAddress['latitude'] != null &&
                      companyAddress['longitude'] != null) {
                    // Conversion sécurisée des coordonnées
                    double? companyLat;
                    double? companyLng;
                    
                    if (companyAddress['latitude'] != null) {
                      if (companyAddress['latitude'] is num) {
                        companyLat = (companyAddress['latitude'] as num).toDouble();
                      } else if (companyAddress['latitude'] is String) {
                        companyLat = double.tryParse(companyAddress['latitude']);
                      }
                    }
                    
                    if (companyAddress['longitude'] != null) {
                      if (companyAddress['longitude'] is num) {
                        companyLng = (companyAddress['longitude'] as num).toDouble();
                      } else if (companyAddress['longitude'] is String) {
                        companyLng = double.tryParse(companyAddress['longitude']);
                      }
                    }
                    
                    if (companyLat != null && companyLng != null &&
                        !LocationUtils.isWithinRadius(
                          locationProvider.latitude!,
                          locationProvider.longitude!,
                          companyLat,
                          companyLng,
                          locationProvider.radius,
                        )) {
                      return const SizedBox.shrink();
                    }
                  }

                  // Création de l'objet CompanyData
             

                  // Création du PostWidget
                  return PostWidget(
                    post: JobOffer.fromDocument(jobOffers[index]),
                    currentUserId:
                        '', // À remplacer par l'ID de l'utilisateur actuel
                    currentProfileUserId:
                        '', // À remplacer par l'ID du profil actuel
                    onView: () {}, // Callback pour la vue
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
