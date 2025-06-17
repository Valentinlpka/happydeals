import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/utils/location_utils.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/location_filter.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class DealExpressPage extends StatefulWidget {
  const DealExpressPage({super.key});

  @override
  State<DealExpressPage> createState() => _DealExpressPageState();
}

class _DealExpressPageState extends State<DealExpressPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _searchQuery = '';
  String _selectedCategory = 'Toutes';
  List<String> _categories = ['Toutes'];
  double? _selectedLat;
  double? _selectedLng;
  double _selectedRadius = 15.0;
  String _selectedAddress = '';
  bool _isLocationFilterActive = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final userProvider = Provider.of<UserModel>(context, listen: false);
    if (userProvider.latitude != 0.0 && userProvider.longitude != 0.0) {
      setState(() {
        _selectedLat = userProvider.latitude;
        _selectedLng = userProvider.longitude;
        _selectedAddress = '${userProvider.city}, ${userProvider.zipCode}';
        _isLocationFilterActive = true;
      });
    }
  }

  Future<void> _loadCategories() async {
    final companiesSnapshot = await _firestore.collection('companys').get();
    final categories = companiesSnapshot.docs
        .where((doc) => doc.data().containsKey('categorie'))
        .map((doc) => doc['categorie'] as String)
        .toSet()
        .toList();

    setState(() {
      _categories = ['Toutes', ...categories];
    });
  }

  void _showLocationFilterBottomSheet() async {
    await LocationFilterBottomSheet.show(
      context: context,
      onLocationSelected: (lat, lng, radius, address) {
        setState(() {
          _selectedLat = lat;
          _selectedLng = lng;
          _selectedRadius = radius;
          _selectedAddress = address;
        });
      },
      currentLat: _selectedLat,
      currentLng: _selectedLng,
      currentRadius: _selectedRadius,
      currentAddress: _selectedAddress,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Deal Express',
        align: Alignment.center,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.location_on,
                  color:
                      _isLocationFilterActive ? const Color(0xFF4B88DA) : null,
                ),
                onPressed: _showLocationFilterBottomSheet,
              ),
              if (_isLocationFilterActive)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
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
          _buildSearchBar(),
          _buildDealsList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un deal...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4B88DA)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
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
                  SizedBox(
                    height: 80,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((category) {
                          final isSelected = _selectedCategory == category;
                          return FilterChip(
                            selected: isSelected,
                            label: Text(category),
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.grey[800],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                    ),
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

  Widget _buildDealsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('type', isEqualTo: 'express_deal')
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
            child: Center(child: Text('Aucun Deal Express disponible')),
          );
        }

        final deals = snapshot.data!.docs;

        return Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDealsSection(
                  deals,
                  title: 'Près de chez vous',
                  isNearby: true,
                  showVertical: true,
                ),
                if (_selectedLat != null && _selectedLng != null)
                  _buildDealsSection(
                    deals,
                    title: 'Un peu plus loin',
                    isNearby: false,
                    showVertical: false,
                  ),
                _buildDealsSection(
                  deals,
                  title: 'Plus disponible actuellement',
                  showUnavailable: true,
                  showVertical: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Widget>> _processDeals(
    List<QueryDocumentSnapshot<Object?>> deals,
    bool isNearby,
    bool showUnavailable,
    bool showVertical,
  ) async {
    List<Widget> processedDeals = [];

    for (var dealDoc in deals) {
      try {
        final deal = ExpressDeal.fromDocument(dealDoc);
        final companyDoc =
            await _firestore.collection('companys').doc(deal.companyId).get();

        if (!companyDoc.exists) continue;

        final companyData = companyDoc.data() as Map<String, dynamic>;
        final companyCategorie = companyData['categorie'] as String;
        final companyAddress = companyData['adress'] as Map<String, dynamic>;
        final companyLat = companyAddress['latitude'] as double?;
        final companyLng = companyAddress['longitude'] as double?;

        // Filtres
        if (_selectedCategory != 'Toutes' &&
            companyCategorie != _selectedCategory) {
          continue;
        }

        if (_searchQuery.isNotEmpty &&
            !deal.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
          continue;
        }

        final isActive = deal.availableBaskets > 0;
        if (showUnavailable != !isActive) {
          continue;
        }

        // Gestion de la distance
        bool isInRadius = false;
        if (_selectedLat != null &&
            _selectedLng != null &&
            companyLat != null &&
            companyLng != null) {
          isInRadius = LocationUtils.isWithinRadius(
            _selectedLat!,
            _selectedLng!,
            companyLat,
            companyLng,
            _selectedRadius,
          );

          if (isNearby != isInRadius && !showUnavailable) {
            continue;
          }
        } else if (isNearby && !showUnavailable) {
          continue;
        }

        // Création du widget avec PostWidget
        final postWidget = Padding(
          padding: EdgeInsets.only(
            bottom: showVertical ? 8.0 : 0,
            right: !showVertical ? 8.0 : 0,
          ),
          child: SizedBox(
            width: !showVertical ? 300 : null,
            child: PostWidget(
              post: deal,
              currentUserId: currentUserId,
              currentProfileUserId: currentUserId,
              onView: () {},
              companyData: CompanyData(
                name: companyData['name'],
                category: companyData['categorie'] ?? '',
                logo: companyData['logo'],
                cover: companyData['cover'] ?? '',
                rawData: companyData,
              ),
            ),
          ),
        );

        processedDeals.add(postWidget);
      } catch (e) {
        if (!mounted) return processedDeals;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du traitement du deal: $e'),
          ),
        );
      }
    }

    return processedDeals;
  }

  Widget _buildDealsSection(
    List<QueryDocumentSnapshot<Object?>> deals, {
    required String title,
    bool isNearby = false,
    bool showUnavailable = false,
    bool showVertical = false,
  }) {
    return FutureBuilder<List<Widget>>(
      future: _processDeals(deals, isNearby, showUnavailable, showVertical),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (showVertical)
              Column(children: snapshot.data!)
            else
              SizedBox(
                height: 400, // Augmenté pour accommoder le PostWidget
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: snapshot.data!,
                ),
              ),
          ],
        );
      },
    );
  }
}
