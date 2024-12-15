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
import 'package:happy/screens/marketplace/ad_list_page.dart';
import 'package:happy/screens/post_type_page/code_promo_page.dart';
import 'package:happy/screens/post_type_page/companys_page.dart';
import 'package:happy/screens/post_type_page/deal_express_page.dart';
import 'package:happy/screens/post_type_page/happy_deals_page.dart';
import 'package:happy/screens/post_type_page/jeux_concours_page.dart';
import 'package:happy/screens/post_type_page/job_offer_page.dart';
import 'package:happy/screens/post_type_page/parrainage.dart';
import 'package:happy/screens/service_list_page.dart';
import 'package:happy/widgets/bottom_sheet_profile.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/navigation_item.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late String currentUserId;
  List<CombinedItem> _feedItems = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _displayedPostIds = {}; // Ajoutez cette ligne

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      title: 'Entreprises',
      icon: Icons.business_center, // Icône d'entreprise/business
      page: const CompaniesPage(),
    ),
    NavigationItem(
      title: 'Deal Express',
      icon: Icons.flash_on, // Icône éclair pour la rapidité/instantanéité
      page: const DealExpressPage(),
    ),
    NavigationItem(
      title: 'Happy Deals',
      icon: Icons.local_offer, // Icône étiquette pour les offres
      page: const HappyDealsPage(),
    ),
    NavigationItem(
      title: 'Code Promo',
      icon: Icons.confirmation_number, // Icône ticket/coupon
      page: const CodePromoPage(),
    ),
    NavigationItem(
      title: 'Emplois',
      icon: Icons.work_outline, // Icône mallette de travail
      page: const JobOffersPage(),
    ),
    NavigationItem(
      title: 'Jeux Concours',
      icon: Icons.emoji_events, // Icône trophée pour les concours
      page: const JeuxConcoursPage(),
    ),
    NavigationItem(
      title: 'Offre de parrainage',
      icon: Icons.people_outline, // Icône de personnes pour le parrainage
      page: const ParraiangePage(),
    ),
    NavigationItem(
      title: 'Services',
      icon: Icons.miscellaneous_services, // Icône engrenage pour les services
      page: const ServiceListPage(),
    ),
    NavigationItem(
      title: 'Marketplace',
      icon: Icons.storefront, // Icône boutique pour la marketplace
      page: const AdListPage(),
    ),
  ];

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
      _displayedPostIds.clear();
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

      // 2. Maintenant charger le feed avec les données utilisateur garanties
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
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // Charge plus de contenu quand on est à 200 pixels de la fin
    if (currentScroll >= (maxScroll - 200)) {
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final userProvider = Provider.of<UserModel>(context, listen: false);

      final lastItem = _feedItems.isNotEmpty ? _feedItems.last : null;
      final newItems = await homeProvider.loadMoreUnifiedFeed(
        userProvider.likedCompanies,
        userProvider.followedUsers,
        lastItem,
      );

      if (mounted) {
        setState(() {
          for (var item in newItems) {
            // Vérifiez que l'item n'existe pas déjà
            if (item.type == 'post') {
              final postData = item.item as Map<String, dynamic>;
              final uniqueId = postData['uniqueId'] as String;

              if (!_displayedPostIds.contains(uniqueId)) {
                _displayedPostIds.add(uniqueId);
                _feedItems.add(item);
              }
            } else {
              _feedItems.add(item);
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildNavigationButtons(),
            Divider(
              color: Colors.grey[300], // Couleur
              thickness: 1, // Épaisseur
              height:
                  20, // Hauteur totale (incluant l'espace au-dessus et en-dessous)
            ),
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

  Widget _buildNavigationButtons() {
    // Map des dégradés pour chaque type
    final Map<String, LinearGradient> gradients = {
      'Entreprises': const LinearGradient(
        colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Deal Express': const LinearGradient(
        colors: [Color(0xFFE65100), Color(0xFFFF9800)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Happy Deals': const LinearGradient(
        colors: [Color(0xFF00796B), Color(0xFF009688)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Code Promo': const LinearGradient(
        colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Emplois': const LinearGradient(
        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Jeux Concours': const LinearGradient(
        colors: [Color(0xFFC62828), Color(0xFFEF5350)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Offre de parrainage': const LinearGradient(
        colors: [Color(0xFF4527A0), Color(0xFF7E57C2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Services': const LinearGradient(
        colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Marketplace': const LinearGradient(
        colors: [Color(0xFF283593), Color(0xFF5C6BC0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Container(
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _navigationItems.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = _navigationItems[index];
            return Container(
              decoration: BoxDecoration(
                gradient: gradients[item.title],
                borderRadius: BorderRadius.circular(5),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => item.page),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  elevation: 1,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
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
      return ListView.builder(
        controller: _scrollController,
        itemCount: items.length + 1, // +1 pour l'indicateur de chargement
        itemBuilder: (context, index) {
          // Si on est au dernier élément, montrer le loader
          if (index == items.length) {
            if (_isLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              );
            } else {
              return const SizedBox
                  .shrink(); // Widget vide si pas de chargement
            }
          }
          return _buildItem(items[index]);
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
