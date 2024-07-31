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

class _HomeState extends State<Home> with AutomaticKeepAliveClientMixin<Home> {
  static const _pageSize = 10;
  bool _showCompanies = false;
  late String currentUserId;
  late PagingController<DocumentSnapshot?, Map<String, dynamic>>
      _postsPagingController;
  late PagingController<DocumentSnapshot?, Company> _companiesPagingController;
  late Future<void> _initializationFuture;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    _postsPagingController = PagingController(firstPageKey: null);
    _companiesPagingController = PagingController(firstPageKey: null);

    _initializationFuture = _initializeWithRetry();
  }

  Future<void> _initializeWithRetry() async {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    for (int i = 0; i <= _maxRetries; i++) {
      try {
        print("Tentative d'initialisation ${i + 1}', name: 'Home");
        await Future.delayed(Duration(seconds: 1 * (i + 1)));
        await homeProvider.loadSavedLocation();
        _retryCount = 0;
        _postsPagingController.addPageRequestListener(_fetchPostsPage);
        _companiesPagingController.addPageRequestListener(_fetchCompaniesPage);
        print("Initialisation réussie', name: 'Home");
        return;
      } catch (e, stackTrace) {
        print(
          "Erreur lors de l'initialisation (tentative ${i + 1}): $e",
        );
        if (i == _maxRetries) {
          homeProvider.setError(e.toString());
          rethrow;
        }
      }
    }
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _retryCount++;
      _initializationFuture = _initializeWithRetry();
    });
  }

  Future<void> _initializeData() async {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    try {
      await homeProvider.loadSavedLocation();
      print(homeProvider.currentPosition);
    } catch (e) {
      if (mounted) {
        _showLocationBottomSheet();
      }
    }
    _postsPagingController.addPageRequestListener(_fetchPostsPage);
    _companiesPagingController.addPageRequestListener(_fetchCompaniesPage);
    Future.microtask(() {
      if (mounted) {
        homeProvider.notifyLocationLoaded();
      }
    });
  }

  @override
  void dispose() {
    _postsPagingController.dispose();
    _companiesPagingController.dispose();
    super.dispose();
  }

  Future<void> _fetchPostsPage(DocumentSnapshot? pageKey) async {
    try {
      print("Début du chargement des posts");
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final newPosts =
          await homeProvider.fetchPostsWithCompanyData(pageKey, _pageSize);
      print("Posts récupérés: ${newPosts.length}");

      final isLastPage = newPosts.length < _pageSize;
      if (isLastPage) {
        print("Dernière page de posts atteinte");
        _postsPagingController.appendLastPage(newPosts);
      } else {
        final lastPostId = newPosts.last['post'].id;
        print("Chargement de la page suivante après le post: $lastPostId");
        final nextPageKey = await FirebaseFirestore.instance
            .collection('posts')
            .doc(lastPostId)
            .get();
        _postsPagingController.appendPage(newPosts, nextPageKey);
      }
      print("Chargement des posts terminé avec succès");
    } catch (error) {
      print("Erreur lors du chargement des posts: $error");
      _postsPagingController.error = error;
    }
  }

// Faites de même pour _fetchCompaniesPage
  Future<void> _fetchCompaniesPage(DocumentSnapshot? pageKey) async {
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Erreur: ${snapshot.error}'),
                    if (_retryCount < _maxRetries)
                      ElevatedButton(
                        onPressed: _retryInitialization,
                        child: const Text('Réessayer'),
                      )
                    else
                      const Text(
                          'Nombre maximum de tentatives atteint. Veuillez réessayer plus tard.'),
                  ],
                ),
              );
            }
            return _buildHomeContent();
          },
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, _) {
        if (homeProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (homeProvider.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Erreur: ${homeProvider.errorMessage}'),
                ElevatedButton(
                  onPressed: _retryInitialization,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildLocationBar(),
                    _buildCategoryButtons(),
                  ],
                ),
              ),
              _showCompanies ? _buildCompanyList() : _buildPostList(),
            ],
          ),
        );
      },
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

  Widget _buildLocationBar() {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, _) {
        return GestureDetector(
          onTap: _showLocationBottomSheet,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
        firstPageErrorIndicatorBuilder: (context) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  'Erreur lors du chargement des posts: ${_postsPagingController.error}'),
              ElevatedButton(
                onPressed: () => _postsPagingController.refresh(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        newPageErrorIndicatorBuilder: (context) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Erreur lors du chargement de la page suivante'),
              ElevatedButton(
                onPressed: () =>
                    _postsPagingController.retryLastFailedRequest(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
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

  Future<void> _handleRefresh() async {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    await homeProvider.loadSavedLocation();
    homeProvider.clearCache();
    _postsPagingController.refresh();
    _companiesPagingController.refresh();
  }
}
