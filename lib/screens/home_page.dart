import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/combined_item.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/marketplace/ad_detail_page.dart';
import 'package:happy/widgets/bottom_sheet_profile.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/filtered_button.dart';
import 'package:happy/widgets/postwidget.dart';
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
      _feedItems.clear();
    });

    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final userProvider = Provider.of<UserModel>(context, listen: false);

      // 1. S'assurer que les données utilisateur sont chargées en premier
      if (userProvider.likedCompanies.isEmpty ||
          userProvider.followedUsers.isEmpty) {
        if (kDebugMode) {
          print("Chargement des données utilisateur...");
        }
        await userProvider.loadUserData();
      }

      // 2. Vérifier la position et la charger si nécessaire

      // 3. Maintenant charger le feed avec les données utilisateur garanties
      if (kDebugMode) {
        print(
            "Nombre d'entreprises likées avant chargement: ${userProvider.likedCompanies.length}");
        print(
            "Nombre d'utilisateurs suivis avant chargement: ${userProvider.followedUsers.length}");
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Une erreur est survenue lors du chargement des données.'),
          ),
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
              GestureDetector(
                onTap: () => showProfileBottomSheet(context),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(2), // Épaisseur du bord en dégradé
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            Colors.white, // Fond blanc entre le bord et l'image
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage(usersProvider.profileUrl),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Salut ${usersProvider.firstName} !",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
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
          case 'Produits':
            return post.type == 'product';
          case 'Post':
            return post.type == 'news';
        }
      }
      return false;
    }).toList();
  }

  Widget _buildItem(CombinedItem item) {
    if (item.type == 'post') {
      final postData = item.item;
      final post = postData['post'] as Post;

      // Conversion explicite des Maps
      final companyData = Map<String, dynamic>.from(postData['company'] ?? {});
      final sharedByUserData = postData['sharedByUser'] != null
          ? Map<String, dynamic>.from(postData['sharedByUser']!)
          : null;
      final isAd = postData['isAd'] as bool? ?? false;

      if (post is SharedPost && isAd) {
        // Gestion des annonces partagées
        final adData =
            Map<String, dynamic>.from(postData['originalContent'] ?? {});

        try {
          final ad = Ad.fromMap(adData, adData['id'] ?? post.originalPostId);

          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: PostWidget(
              key: ValueKey('${post.id}_${post.originalPostId}_ad'),
              post: post,
              ad: ad,
              companyCover: '',
              companyCategorie: '',
              companyName: '',
              companyLogo: '',
              currentUserId: currentUserId,
              sharedByUserData: sharedByUserData,
              currentProfileUserId: currentUserId,
              onView: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdDetailPage(ad: ad),
                  ),
                );
              },
              companyData: const {},
            ),
          );
        } catch (e) {
          return const SizedBox.shrink(); // Widget vide en cas d'erreur
        }
      } else {
        // Gestion des posts normaux
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
      }
    } else {
      // Gestion des autres types (companies)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: CompanyCard(item.item as Company),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
