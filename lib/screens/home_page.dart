import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/web_adress_search.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final String currentUserId =
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  final PagingController<DocumentSnapshot?, Map<String, dynamic>>
      _pagingController = PagingController(firstPageKey: null);
  final PagingController<DocumentSnapshot?, Company>
      _companiesPagingController = PagingController(firstPageKey: null);

  static const _pageSize = 10;
  bool _showCompanies = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeProvider>(context, listen: false).loadSavedLocation();
    });
    _pagingController.addPageRequestListener(_fetchPage);
    _companiesPagingController.addPageRequestListener(_fetchCompanyPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _companiesPagingController.dispose();
    super.dispose();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateSingleCompany(QueryDocumentSnapshot doc) async {
    try {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Map<String, dynamic>? addressData =
          data['adress'] as Map<String, dynamic>?;

      if (addressData == null) {
        print('Données d\'adresse manquantes pour l\'entreprise ${doc.id}');
        return;
      }

      String address =
          '${addressData['adresse']}, ${addressData['code_postal']}, ${addressData['ville']}, France';

      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        Location location = locations.first;

        // Mettre à jour le document avec les nouvelles coordonnées
        await _firestore.collection('companys').doc(doc.id).update({
          'adress.latitude': location.latitude,
          'adress.longitude': location.longitude,
        });

        print(
            'Entreprise ${doc.id} mise à jour avec les coordonnées: ${location.latitude}, ${location.longitude}');
      } else {
        print(
            'Aucune coordonnée trouvée pour l\'adresse de l\'entreprise ${doc.id}');
      }
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'entreprise ${doc.id}: $e');
    }
  }

  Future<void> _fetchCompanyPage(DocumentSnapshot? pageKey) async {
    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final newCompanies =
          await homeProvider.fetchCompanies(pageKey, _pageSize);

      final isLastPage = newCompanies.length < _pageSize;
      if (isLastPage) {
        _companiesPagingController.appendLastPage(newCompanies);
      } else {
        final lastCompany = newCompanies.last;
        final nextPageKey = await FirebaseFirestore.instance
            .collection('companys')
            .doc(lastCompany.id)
            .get();
        _companiesPagingController.appendPage(newCompanies, nextPageKey);
      }
    } catch (error) {
      _companiesPagingController.error = error;
    }
  }

  Future<void> _fetchPage(DocumentSnapshot? pageKey) async {
    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final newPosts =
          await homeProvider.fetchPostsWithCompanyData(pageKey, _pageSize);

      final isLastPage = newPosts.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newPosts);
      } else {
        final lastPostId = newPosts.last['post'].id;
        final nextPageKey = await FirebaseFirestore.instance
            .collection('posts')
            .doc(lastPostId)
            .get();
        _pagingController.appendPage(newPosts, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<HomeProvider>(
          builder: (context, homeProvider, _) {
            if (homeProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildLocationBar(homeProvider),
                        _buildCategoryButtons(),
                      ],
                    ),
                  ),
                  _showCompanies ? _buildCompanyList() : _buildPostList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<UserModel>(
      builder: (context, usersProvider, _) {
        return Container(
          padding: const EdgeInsets.all(16.0),
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

  Widget _buildLocationBar(HomeProvider homeProvider) {
    return GestureDetector(
      onTap: () => _showLocationBottomSheet(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
  }

  void _showLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<HomeProvider>(
        builder: (context, homeProvider, _) {
          return DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.75,
            expand: false,
            builder: (_, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    "Localisation",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildAddressSearch(homeProvider),
                  const SizedBox(height: 20),
                  _buildRadiusSelector(homeProvider),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await homeProvider
                          .applyChanges(); // Appliquer les changements
                      setState(() {}); // Forcer la reconstruction du widget
                      _pagingController.refresh();
                      _companiesPagingController.refresh();
                    },
                    child: const Text("Appliquer"),
                  ),
                ],
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
          prefixIcon: Icon(Icons.location_on),
          border: OutlineInputBorder(),
        ),
        debounceTime: 800,
        countries: const ["fr"],
        isLatLngRequired: true,
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

  Widget _buildCategoryButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCategoryButton("Posts", !_showCompanies),
          _buildCategoryButton("Entreprises", _showCompanies),
        ],
      ),
    );
  }

  Widget _buildCategoryButton(String title, bool isSelected) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _showCompanies = title == "Entreprises";
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black,
      ),
      child: Text(title),
    );
  }

  Widget _buildCompanyList() {
    return PagedSliverList<DocumentSnapshot?, Company>(
      pagingController: _companiesPagingController,
      builderDelegate: PagedChildBuilderDelegate<Company>(
        noItemsFoundIndicatorBuilder: (_) => const Center(
          child: Text('Aucune entreprise trouvée à proximité'),
        ),
        itemBuilder: (context, company, index) => CompanyCard(company),
      ),
    );
  }

  Widget _buildPostList() {
    return PagedSliverList<DocumentSnapshot?, Map<String, dynamic>>(
      pagingController: _pagingController,
      builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
        noItemsFoundIndicatorBuilder: (_) => const Center(
          child: Text(
              'Aucun post à proximité, veuillez changer votre localisation'),
        ),
        itemBuilder: (context, postData, index) {
          final post = postData['post'] as Post;
          final companyData = postData['company'] as Map<String, dynamic>;
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: PostWidget(
              key: ValueKey(post.id),
              post: post,
              companyCategorie: companyData['categorie'] ?? '',
              companyName: companyData['name'] ?? '',
              companyLogo: companyData['logo'] ?? '',
              currentUserId: currentUserId,
              onView: () {
                // Logique d'affichage du post
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    await homeProvider.refreshPosts();
    _pagingController.refresh();
    _companiesPagingController.refresh();
  }
}
