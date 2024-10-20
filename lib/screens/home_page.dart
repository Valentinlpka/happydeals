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
import 'package:happy/widgets/filtered_button.dart';
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
  String _selectedFilter = 'Tous';
  List<CombinedItem> _feedItems = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final userProvider = Provider.of<UserModel>(context, listen: false);

      await homeProvider.loadSavedLocation();
      if (homeProvider.currentPosition == null) {
        await homeProvider.showLocationSelectionBottomSheet(context);
      }
      final feedItems = await homeProvider.loadUnifiedFeed(
        userProvider.likedCompanies,
        userProvider.followedUsers,
      );

      if (mounted) {
        setState(() {
          _feedItems = feedItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Une erreur est survenue lors du chargement des données.')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    // Implement pagination logic here
    // This should call a method in HomeProvider to fetch more data
    // and append it to _feedItems
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildLocationBar(),
            FilterButtons(
              selectedFilter: _selectedFilter,
              onFilterChanged: (filter) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
            if (_isLoading)
              const LinearProgressIndicator()
            else
              const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: _buildContentList(_feedItems),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<UserModel>(
      builder: (context, usersProvider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
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
          onTap: () => _showLocationBottomSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  Widget _buildFilterButton(String title) {
    bool isSelected = _selectedFilter == title;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
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

  Widget _buildContentList(List<CombinedItem> items) {
    if (_isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      return const Center(child: Text('Aucun élément trouvé'));
    } else {
      final filteredItems = _applyFilter(items);
      return ListView.builder(
        controller: _scrollController,
        itemCount: filteredItems.length + 1,
        itemBuilder: (context, index) {
          if (index == filteredItems.length) {
            return _buildLoadingIndicator();
          }
          return _buildItem(filteredItems[index]);
        },
      );
    }
  }

  Widget _buildLoadingIndicator() {
    return _isLoading
        ? const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          )
        : const SizedBox.shrink();
  }

  Future<void> _handleRefresh() async {
    await _loadData();
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
      final sharedByUserData =
          postData['sharedByUser'] as Map<String, dynamic>?;
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
          sharedByUserData: sharedByUserData,
          currentProfileUserId: currentUserId,
          onView: () {
            // Logique d'affichage du post
          },
          companyData: companyData,
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: CompanyCard(item.item as Company),
      );
    }
  }

  void _showLocationBottomSheet(BuildContext context) {
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
                                WidgetStateProperty.all(Colors.blue[800]),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await homeProvider.applyChanges();
                            _loadData();
                          },
                          child: const Text("Appliquer"),
                        ),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
