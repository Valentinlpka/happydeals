import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  static const _pageSize = 10;
  bool _showCompanies = false;
  late String currentUserId;
  late PagingController<DocumentSnapshot?, Map<String, dynamic>>
      _postsPagingController;
  late PagingController<DocumentSnapshot?, Company> _companiesPagingController;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    _postsPagingController = PagingController(firstPageKey: null);
    _companiesPagingController = PagingController(firstPageKey: null);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().loadSavedLocation();
    });

    _postsPagingController.addPageRequestListener(_fetchPostsPage);
    _companiesPagingController.addPageRequestListener(_fetchCompaniesPage);
  }

  @override
  void dispose() {
    _postsPagingController.dispose();
    _companiesPagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPostsPage(DocumentSnapshot? pageKey) async {
    try {
      final homeProvider = context.read<HomeProvider>();
      final newPosts =
          await homeProvider.fetchPostsWithCompanyData(pageKey, _pageSize);

      final isLastPage = newPosts.length < _pageSize;
      if (isLastPage) {
        _postsPagingController.appendLastPage(newPosts);
      } else {
        final lastPostId = newPosts.last['post'].id;
        final nextPageKey = await FirebaseFirestore.instance
            .collection('posts')
            .doc(lastPostId)
            .get();
        _postsPagingController.appendPage(newPosts, nextPageKey);
      }
    } catch (error) {
      _postsPagingController.error = error;
    }
  }

  Future<void> _fetchCompaniesPage(DocumentSnapshot? pageKey) async {
    try {
      final homeProvider = context.read<HomeProvider>();
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
      onTap: _showLocationBottomSheet,
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
                      await homeProvider.applyChanges();
                      setState(() {});
                      _postsPagingController.refresh();
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
      pagingController: _postsPagingController,
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
    final homeProvider = context.read<HomeProvider>();
    homeProvider.clearCache();
    _postsPagingController.refresh();
    _companiesPagingController.refresh();
  }
}
