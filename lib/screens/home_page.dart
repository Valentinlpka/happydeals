import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/postwidget.dart';
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
  final TextEditingController _searchController = TextEditingController();
  final PagingController<DocumentSnapshot?, Map<String, dynamic>>
      _pagingController = PagingController(firstPageKey: null);

  final PagingController<DocumentSnapshot?, Company>
      _companiesPagingController = PagingController(firstPageKey: null);

  static const _pageSize = 30;
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
    _searchController.dispose();
    _companiesPagingController.dispose();

    super.dispose();
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
        final lastCompanyId = newCompanies.last.id;
        final nextPageKey = await FirebaseFirestore.instance
            .collection('companys')
            .doc(lastCompanyId)
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
                        _buildSearchBar(homeProvider),
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

  Widget _buildCompanyList() {
    return PagedSliverList<DocumentSnapshot?, Company>(
      pagingController: _companiesPagingController,
      builderDelegate: PagedChildBuilderDelegate<Company>(
        noItemsFoundIndicatorBuilder: (_) => const Center(
          child: Text(
            'Aucune entreprise trouvée à proximité',
            textAlign: TextAlign.center,
          ),
        ),
        itemBuilder: (context, company, index) {
          return CompanyCard(company);
        },
      ),
    );
  }

  Widget _buildCategoryButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCategoryButton("Posts", !_showCompanies),
            _buildCategoryButton("Entreprises", _showCompanies),
            // Ajoutez d'autres boutons de catégorie ici si nécessaire
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryButton(String title, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
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
                      maxLines: 3,
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

  Widget _buildSearchBar(HomeProvider homeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
      ),
      child: GooglePlaceAutoCompleteTextField(
        textEditingController: homeProvider.addressController,
        googleAPIKey: "AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc",
        inputDecoration: const InputDecoration(
          alignLabelWithHint: true,
          contentPadding: EdgeInsets.all(11),
          hintText: "Rechercher une ville",
          prefixIcon: Icon(Icons.location_on),
          border: InputBorder.none,
        ),
        debounceTime: 800,
        countries: const ["fr"],
        isLatLngRequired: true,
        containerHorizontalPadding: 5,
        containerVerticalPadding: 5,
        getPlaceDetailWithLatLng: (Prediction prediction) {
          homeProvider.updateLocationFromPrediction(prediction);
          _pagingController.refresh();
        },
        itemClick: (Prediction prediction) {
          homeProvider.addressController.text =
              prediction.description ?? "Rien";
          homeProvider.addressController.selection = TextSelection.fromPosition(
              TextPosition(offset: homeProvider.addressController.text.length));
        },
      ),
    );
  }

  Widget _buildRadiusSelector(HomeProvider homeProvider) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Rayon: ", style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<double>(
            value: homeProvider.selectedRadius,
            items: [5.0, 10.0, 15.0, 20.0, 50.0].map((double value) {
              return DropdownMenuItem<double>(
                  value: value, child: Text('$value km'));
            }).toList(),
            onChanged: (newValue) {
              homeProvider.setSelectedRadius(newValue!);
              _pagingController.refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return PagedSliverList<DocumentSnapshot?, Map<String, dynamic>>(
      pagingController: _pagingController,
      builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
        noItemsFoundIndicatorBuilder: (_) => const Center(
          child: Text(
              'Aucun post à proximité, veuillez changer votre localisation',
              textAlign: TextAlign.center),
        ),
        itemBuilder: (context, postData, index) {
          final post = postData['post'] as Post;
          final companyData = postData['company'] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.all(10.0),
            child: PostWidget(
              key: ValueKey(post.id),
              post: post,
              companyCategorie: companyData['categorie'] ?? '',
              companyName: companyData['name'] ?? '',
              companyLogo: companyData['logo'] ?? '',
              currentUserId: currentUserId,
              onView: () {
                // Logique d'affichage
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    await homeProvider.getCurrentLocation();
    await Future.delayed(const Duration(milliseconds: 500));

    _pagingController.refresh();

    setState(() {});
  }

  Future<Map<String, dynamic>> _getCompanyData(String companyId) async {
    DocumentSnapshot companyDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();

    return companyDoc.data() as Map<String, dynamic>;
  }
}
