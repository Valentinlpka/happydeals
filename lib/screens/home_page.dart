import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/classes/combined_item.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/web_adress_search.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late String currentUserId;
  late Future<List<CombinedItem>> _combinedItemsFuture;
  String _selectedFilter = 'Tous';
  List<CombinedItem> _items = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      _combinedItemsFuture = homeProvider.loadAllData(); // Initialisez ici
      final items = await _combinedItemsFuture;
      setState(() {
        _items = items ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _loadData();
            });
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 10),
                    _buildLocationBar(),
                    const SizedBox(height: 10),
                    _buildFilterButtons(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              _buildCombinedList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<UserModel>(
      builder: (context, usersProvider, _) {
        return Container(
          padding: const EdgeInsets.only(left: 20.0, top: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(usersProvider.profileUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Salut ${usersProvider.firstName} !",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      usersProvider.dailyQuote,
                      style: const TextStyle(color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationBar() {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, _) {
        return GestureDetector(
          onTap: _showLocationBottomSheet,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    homeProvider.currentAddress,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.blue),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterButton('Tous'),
            _buildFilterButton('Entreprises'),
            _buildFilterButton('Deals Express'),
            _buildFilterButton('Happy Deals'),
            _buildFilterButton('Offres d\'emploi'),
            _buildFilterButton('Parrainage'),
            _buildFilterButton('Jeux concours'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String title) {
    bool isSelected = _selectedFilter == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: isSelected ? Colors.white : Colors.black,
          backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
        ),
        onPressed: () {
          setState(() {
            _selectedFilter = title;
          });
        },
        child: Text(title),
      ),
    );
  }

  Widget _buildCombinedList() {
    return FutureBuilder<List<CombinedItem>>(
      future: _combinedItemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return SliverFillRemaining(
            child: Center(child: Text('Erreur: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
                child: Text(
                    'Aucun élément trouvé à proximité, veuillez changer votre localisation')),
          );
        } else {
          final filteredItems = _applyFilter(snapshot.data!);
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildItem(filteredItems[index]),
              childCount: filteredItems.length,
            ),
          );
        }
      },
    );
  }

  List<CombinedItem> _applyFilter(List<CombinedItem> items) {
    if (_selectedFilter == 'Tous') return items;
    return items.where((item) {
      if (_selectedFilter == 'Entreprises' && item.type == 'company') {
        return true;
      }
      if (item.type == 'post') {
        final post = item.item['post'] as Post;
        switch (_selectedFilter) {
          case 'Deals Express':
            return post.type == 'express_deal';
          case 'Happy Deals':
            return post.type == 'happy_deal';
          case 'Offres d\'emploi':
            return post.type == 'job_offer';
          case 'Parrainage':
            return post.type == 'referral';
          case 'Jeux concours':
            return post.type == 'contest';
        }
      }
      return false;
    }).toList();
  }

  Widget _buildItem(CombinedItem item) {
    if (item.type == 'post') {
      final postData = item.item;
      final post = postData['post'] as Post;
      final companyData = postData['company'] as Map<String, dynamic>;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: PostWidget(
          key: ValueKey(post.id),
          post: post,
          companyCover: companyData['cover'],
          companyCategorie: companyData['categorie'] ?? '',
          companyName: companyData['name'] ?? '',
          companyLogo: companyData['logo'] ?? '',
          currentUserId: currentUserId,
          onView: () {
            // Logique d'affichage du post
          },
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: CompanyCard(item.item as Company),
      );
    }
  }

  void _showLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<HomeProvider>(
        builder: (context, homeProvider, _) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Localisation",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        _buildAddressSearch(homeProvider),
                        const SizedBox(height: 20),
                        _buildRadiusSelector(homeProvider),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ButtonStyle(
                              backgroundColor:
                                  WidgetStatePropertyAll(Colors.blue[800])),
                          onPressed: () async {
                            Navigator.pop(context);
                            await homeProvider.applyChanges();
                            setState(() {
                              _loadData();
                            });
                          },
                          child: const Text("Appliquer"),
                        ),
                        SizedBox(
                            height: MediaQuery.of(context).viewInsets.bottom),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddressSearch(HomeProvider homeProvider) {
    if (kIsWeb) {
      return WebAddressSearch(
        homeProvider: homeProvider,
        onLocationUpdated: () {},
      );
    } else {
      return GooglePlaceAutoCompleteTextField(
        textEditingController: homeProvider.addressController,
        googleAPIKey: "AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc",
        inputDecoration: const InputDecoration(
          hintText: "Rechercher une ville",
          alignLabelWithHint: true,
          icon: Padding(
            padding: EdgeInsets.only(left: 10.0),
            child: Icon(Icons.location_on),
          ),
          isCollapsed: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          border: InputBorder.none,
        ),
        debounceTime: 800,
        countries: const ["fr"],
        isLatLngRequired: true,
        seperatedBuilder: const Divider(color: Colors.black12, height: 2),
        getPlaceDetailWithLatLng: (Prediction prediction) async {
          await homeProvider.updateLocationFromPrediction(prediction);
        },
        itemClick: (Prediction prediction) {
          homeProvider.addressController.text = prediction.description ?? "";
        },
      );
    }
  }

  Widget _buildRadiusSelector(HomeProvider homeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Rayon de recherche"),
        DropdownButton<double>(
          value: homeProvider.selectedRadius,
          items: [5.0, 10.0, 15.0, 20.0, 40.0, 50.0].map((double value) {
            return DropdownMenuItem<double>(
              value: value,
              child: Text('$value km'),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              homeProvider.setSelectedRadius(newValue);
            }
          },
        ),
      ],
    );
  }
}
