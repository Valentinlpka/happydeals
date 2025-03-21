import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/combined_item.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/match_market/match_market_intro_page.dart';
import 'package:happy/screens/post_type_page/code_promo_page.dart';
import 'package:happy/screens/post_type_page/companys_page.dart';
import 'package:happy/screens/post_type_page/deal_express_page.dart';
import 'package:happy/screens/post_type_page/happy_deals_page.dart';
import 'package:happy/screens/post_type_page/jeux_concours_page.dart';
import 'package:happy/screens/post_type_page/job_offer_page.dart';
import 'package:happy/screens/post_type_page/parrainage.dart';
import 'package:happy/screens/search_page.dart';
import 'package:happy/screens/service_list_page.dart';
import 'package:happy/screens/shop/products_page.dart';
import 'package:happy/screens/troc-et-echange/ad_detail_page.dart';
import 'package:happy/screens/troc-et-echange/ad_list_page.dart';
import 'package:happy/widgets/bottom_sheet_profile.dart';
import 'package:happy/widgets/navigation_item.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> with AutomaticKeepAliveClientMixin {
  late String currentUserId;
  final ScrollController _scrollController = ScrollController();

  // Ajout d'un indicateur de premier chargement
  bool _isFirstLoad = true;

  @override
  bool get wantKeepAlive => true; // Garde la page en vie

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      title: 'Annuaire',
      icon: Icons.business_center, // Icône d'entreprise/business
      page: const CompaniesPage(),
    ),
    NavigationItem(
      title: 'Produit',
      icon: Icons.shopping_bag_outlined, // Icône d'entreprise/business
      page: const ProductsPage(),
    ),
    NavigationItem(
      title: 'Deal Express',
      icon: Icons.flash_on, // Icône éclair pour la rapidité/instantanéité
      page: const DealExpressPage(),
    ),
    NavigationItem(
      title: 'Happy Deals',
      icon: Icons.local_offer,
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
      title: 'Parrainage',
      icon: Icons.people_outline, // Icône de personnes pour le parrainage
      page: const ParraiangePage(),
    ),
    NavigationItem(
      title: 'Services',
      icon: Icons.calendar_today_outlined, // Icône engrenage pour les services
      page: const ServiceListPage(),
    ),
    NavigationItem(
      title: 'Troc & Échange',
      icon: Icons.storefront, // Icône boutique pour la marketplace
      page: const AdListPage(),
    ),
    NavigationItem(
      title: 'Match Market',
      icon: Icons.local_fire_department_outlined, // Icône d'entreprise/business
      page: const MatchMarketIntroPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    _scrollController.addListener(_onScroll);
    // Initialisation différée pour éviter les problèmes de context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeed();
    });
  }

  Future<void> _initializeFeed() async {
    final userProvider = Provider.of<UserModel>(context, listen: false);
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

    // Vérifier si les données sont déjà chargées
    if (homeProvider.currentFeedItems.isNotEmpty) {
      setState(() => _isFirstLoad = false);
      return;
    }

    // Charger les données en parallèle
    await Future.wait([
      userProvider.loadUserData(),
      homeProvider.initializeFeed(
        userProvider.likedCompanies,
        userProvider.followedUsers,
      ),
    ]);

    // Indiquer que le premier chargement est terminé
    setState(() => _isFirstLoad = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Nécessaire pour AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildNavigationButtons(),
            Divider(
              color: Colors.grey[300],
              thickness: 1,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: _buildStreamBuilder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonPost() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey[200]!,
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du post
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar skeleton
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom skeleton
                        Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Date skeleton
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Image skeleton
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[300],
            ),
            // Contenu skeleton
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne de texte 1
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Ligne de texte 2
                  Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Actions skeleton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      3,
                      (index) => Container(
                        width: 60,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamBuilder() {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, _) {
        return StreamBuilder<List<CombinedItem>>(
          stream: homeProvider.feedStream,
          builder: (context, snapshot) {
            // Afficher le skeleton pendant le chargement avec priorité au premier chargement
            if ((_isFirstLoad ||
                    (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData)) &&
                homeProvider.currentFeedItems.isEmpty) {
              return ListView.builder(
                padding: EdgeInsets.zero,
                physics:
                    const NeverScrollableScrollPhysics(), // Empêche le défilement pendant le chargement
                itemCount: 3, // Nombre de skeletons à afficher
                itemBuilder: (context, index) => _buildSkeletonPost(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erreur: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _handleRefresh,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final items = snapshot.data ?? homeProvider.currentFeedItems;
            return _buildContentList(items);
          },
        );
      },
    );
  }

  // Modifiez _handleRefresh pour utiliser le nouveau système
  Future<void> _handleRefresh() async {
    final userProvider = Provider.of<UserModel>(context, listen: false);
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

    // Vérifier si le dernier refresh était il y a moins de 2 minutes
    if (homeProvider.lastRefreshTime != null) {
      final timeSinceLastRefresh =
          DateTime.now().difference(homeProvider.lastRefreshTime!);
      if (timeSinceLastRefresh < const Duration(minutes: 2)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Veuillez patienter quelques minutes avant de rafraîchir à nouveau'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    await homeProvider.loadUnifiedFeed(
      userProvider.likedCompanies,
      userProvider.followedUsers,
      refresh: true,
    );
  }

  Widget _buildNavigationButtons() {
    // Map des dégradés pour chaque type
    final Map<String, LinearGradient> gradients = {
      'Annuaire': const LinearGradient(
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
      'Parrainage': const LinearGradient(
        colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Services': const LinearGradient(
        colors: [Color(0xFF6B48FF), Color(0xFF8466FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Troc & Échange': const LinearGradient(
        colors: [Color(0xFF283593), Color(0xFF5C6BC0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Match Market': const LinearGradient(
        colors: [
          Color.fromARGB(251, 209, 142, 8),
          Color.fromARGB(255, 237, 59, 23)
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'Produit': const LinearGradient(
        colors: [
          Color.fromARGB(255, 234, 46, 159),
          Color.fromARGB(255, 237, 23, 109)
        ],
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
          cacheExtent: 500,
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
    return Consumer2<UserModel, NotificationProvider>(
      builder: (context, usersProvider, notificationProvider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
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
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundImage:
                                NetworkImage(usersProvider.profileUrl),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (notificationProvider.hasUnreadNotifications)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          notificationProvider.notifications
                              .where((n) => !n.isRead)
                              .length
                              .toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
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
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey[50]!.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 2,
                    ),
                  ],
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Colors.black87),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SearchPage()),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContentList(List<CombinedItem> items) {
    final homeProvider = Provider.of<HomeProvider>(context);

    if (homeProvider.isLoading && items.isEmpty) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        physics:
            const NeverScrollableScrollPhysics(), // Empêche le défilement pendant le chargement
        itemCount: 3,
        itemBuilder: (context, index) => _buildSkeletonPost(),
      );
    } else if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Aucun contenu trouvé'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF186dbc),
                foregroundColor: Colors.white,
              ),
              child: const Text('Actualiser'),
            ),
          ],
        ),
      );
    } else {
      return ListView.builder(
        key: const PageStorageKey('feed-list'),
        cacheExtent:
            2000, // Augmentation du cache pour une meilleure performance
        padding: EdgeInsets.zero,
        addRepaintBoundaries: true,
        addAutomaticKeepAlives: true,
        controller: _scrollController,
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
            if (homeProvider.isLoading) {
              return _buildLoaderItem();
            } else if (!homeProvider.hasMoreData) {
              return _buildEndOfListIndicator();
            }
            return const SizedBox.shrink();
          }
          return RepaintBoundary(
            child: _buildItem(items[index]),
          );
        },
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    const threshold = 0.7; // Déclencher le chargement plus tôt

    if (currentScroll >= (maxScroll * threshold)) {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);

      if (!homeProvider.isLoading && homeProvider.hasMoreData) {
        if (kDebugMode) {
          print("Déclenchement du chargement de plus de posts...");
        }
        _loadMoreData();
      }
    }
  }

  Future<void> _loadMoreData() async {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final userProvider = Provider.of<UserModel>(context, listen: false);

    if (homeProvider.isLoading || !homeProvider.hasMoreData) return;

    final lastItem = homeProvider.currentFeedItems.isNotEmpty
        ? homeProvider.currentFeedItems.last
        : null;

    try {
      await homeProvider.loadMoreUnifiedFeed(
        userProvider.likedCompanies,
        userProvider.followedUsers,
        lastItem,
      );
    } catch (e) {
      // Gestion silencieuse des erreurs de chargement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Réessayer',
              onPressed: () => _loadMoreData(),
            ),
          ),
        );
      }
    }
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
          padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 05.0),
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
      // Gestion des autres types
      return const SizedBox.shrink();
    }
  }

  // Nouveau widget séparé pour l'indicateur de chargement
  Widget _buildLoaderItem() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: const Center(
        child: Column(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF186dbc)),
              ),
            ),
            SizedBox(height: 8),
            Text('Chargement en cours...',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Nouveau widget séparé pour l'indicateur de fin de liste
  Widget _buildEndOfListIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              'Vous avez tout vu !',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Revenez plus tard pour voir plus de contenu',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
