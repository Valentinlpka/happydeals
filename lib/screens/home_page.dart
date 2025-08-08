import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/combined_item.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/match_market/match_market_intro_page.dart';
import 'package:happy/screens/post_type_page/code_promo_page.dart';
import 'package:happy/screens/post_type_page/companys_page_unified.dart';
import 'package:happy/screens/post_type_page/deal_express_page.dart';
import 'package:happy/screens/post_type_page/happy_deals_page.dart';
import 'package:happy/screens/post_type_page/jeux_concours_page.dart';
import 'package:happy/screens/post_type_page/job_offer_page.dart';
import 'package:happy/screens/post_type_page/parrainage.dart';
import 'package:happy/screens/post_type_page/publications_page.dart';
import 'package:happy/screens/search_page.dart';
import 'package:happy/screens/service_list_page.dart';
import 'package:happy/screens/shop/products_page.dart';
import 'package:happy/screens/troc-et-echange/ad_detail_page.dart';
import 'package:happy/screens/troc-et-echange/ad_list_page.dart';
import 'package:happy/services/analytics_service.dart';
import 'package:happy/widgets/bottom_sheet_profile.dart';
import 'package:happy/widgets/navigation_item.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with AutomaticKeepAliveClientMixin {
  final AnalyticsService _analytics = AnalyticsService();
  late String currentUserId;
  final ScrollController _scrollController = ScrollController();
  bool _isInitializing = false;

  @override
  bool get wantKeepAlive => true; // Garde la page en vie

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      title: 'Annuaire',
      icon: Icons.business_center, // Icône d'entreprise/business
      page: const CompaniesPageUnified(),
    ),
    NavigationItem(
      title: 'Publications',
      icon: Icons.article_outlined,
      page: const PublicationsPage(),
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
    _logScreenView();

    // Initialisation différée optimisée
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeed();
    });
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(
      screenName: 'home_page',
      screenClass: 'HomePage',
    );

    // Pour le titre de la page web
    await _analytics.updateWebPageTitle('Accueil');
  }

  Future<void> _initializeFeed() async {
    if (_isInitializing) return;

    _isInitializing = true;
    try {
      final userProvider = Provider.of<UserModel>(context, listen: false);
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);

      // Réinitialiser l'état du provider
      homeProvider.reset();

      // Attendre que les données utilisateur soient chargées
      await userProvider.loadUserData();

      if (userProvider.likedCompanies.isEmpty &&
          userProvider.followedUsers.isEmpty) {
        // Afficher les entreprises proches
        _showNearbyCompanies();
        return;
      }

      // Charger le feed avec les données utilisateur
      await homeProvider.loadUnifiedFeed(
        userProvider.likedCompanies,
        userProvider.followedUsers,
        refresh: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Réessayer',
              onPressed: _initializeFeed,
            ),
          ),
        );
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _showNearbyCompanies() async {
    try {
      final userProvider = Provider.of<UserModel>(context, listen: false);
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);

      // Vérifier si nous avons la localisation de l'utilisateur
      if (!locationProvider.hasLocation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Activez la géolocalisation pour voir les entreprises proches'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Récupérer les entreprises proches
      final companiesSnapshot = await FirebaseFirestore.instance
          .collection('companys')
          .orderBy('name')
          .limit(10)
          .get();

      if (companiesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune entreprise trouvée près de chez vous'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Afficher une boîte de dialogue avec les entreprises proches
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Entreprises proches de chez vous'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: companiesSnapshot.docs.length,
              itemBuilder: (context, index) {
                final company = companiesSnapshot.docs[index].data();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(company['logo'] ?? ''),
                  ),
                  title: Text(company['name'] ?? ''),
                  subtitle: Text(company['categorie'] ?? ''),
                  trailing: ElevatedButton(
                    onPressed: () {
                      userProvider.handleCompanyFollow(
                          companiesSnapshot.docs[index].id);
                      Navigator.pop(context);
                      _initializeFeed();
                    },
                    child: const Text('Suivre'),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        print('Erreur: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
            if (homeProvider.isInitialLoading) {
              return _buildSkeletonList();
            }

            if (snapshot.hasError) {
              return _buildErrorWidget(snapshot.error);
            }

            final items = snapshot.data ?? homeProvider.currentFeedItems;

            if (items.isEmpty) {
              return _buildEmptyState();
            }

            return _buildContentList(items);
          },
        );
      },
    );
  }

  Widget _buildContentList(List<CombinedItem> items) {
    return ListView.builder(
      key: const PageStorageKey('feed-list'),
      cacheExtent: 2000,
      padding: EdgeInsets.zero,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      controller: _scrollController,
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);
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

  // Nouveau widget pour afficher plusieurs skeletons
  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) => _buildSkeletonPost(),
    );
  }

  // Nouveau widget pour l'état d'erreur
  Widget _buildErrorWidget(dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Une erreur est survenue: ${error.toString()}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleRefresh,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // Nouveau widget pour l'état vide
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucun contenu à afficher'),
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
      'Publications': const LinearGradient(
        colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
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

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start, // Changé de center à start
            children: _navigationItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  height: 42,
                  constraints: const BoxConstraints(maxWidth: 160), // Ajout d'une largeur maximale
                  decoration: BoxDecoration(
                    gradient: gradients[item.title],
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => item.page),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, // Réduit de 16 à 12
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 32),
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: Colors.white,
                          size: 16, // Réduit de 18 à 16
                        ),
                        const SizedBox(width: 4), // Réduit de 6 à 4
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13, // Réduit de 14 à 13
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer2<UserModel, NotificationProvider>(
      builder: (context, usersProvider, notificationProvider, _) {
        final String profileUrl = usersProvider.profileUrl.trim();
        final bool hasValidProfileUrl = profileUrl.isNotEmpty && 
            (profileUrl.startsWith('http://') || profileUrl.startsWith('https://'));

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.04,
            vertical: 16,
          ),
          child: SafeArea(
            child: Row(
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => showProfileBottomSheet(context),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.12,
                        height: MediaQuery.of(context).size.width * 0.12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha(22),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: hasValidProfileUrl
                                ? CircleAvatar(
                              radius: MediaQuery.of(context).size.width * 0.06,
                                    backgroundImage: NetworkImage(profileUrl),
                                    backgroundColor: Colors.grey[200],
                                  )
                                : CircleAvatar(
                                    radius: MediaQuery.of(context).size.width * 0.06,
                                    backgroundColor: Colors.grey[200],
                                    child: Icon(
                                      Icons.person,
                                      size: MediaQuery.of(context).size.width * 0.06,
                                      color: Colors.grey[400],
                                    ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.width * 0.08,
                          maxWidth: MediaQuery.of(context).size.width * 0.6,
                        ),
                        child: Text(
                          usersProvider.dailyQuote,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: MediaQuery.of(context).size.width * 0.035,
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.12,
                  height: MediaQuery.of(context).size.width * 0.12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue[700],
                    
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(5),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.search,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.07,
                    ),
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
          ),
        );
      },
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    const threshold = 0.7;

    if (currentScroll >= (maxScroll * threshold)) {
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);

      if (!homeProvider.isLoading && homeProvider.hasMoreData) {
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
    try {
      if (item.type == 'post') {
        final postData = item.item;
        final post = postData['post'] as Post;

        final sharedByUserData = postData['sharedByUser'] != null
            ? Map<String, dynamic>.from(postData['sharedByUser']!)
            : null;
        final isAd = postData['isAd'] as bool? ?? false;

        if (post is SharedPost && isAd) {
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
              ),
            );
          } catch (e) {
            return const SizedBox.shrink();
          }
        } else {
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 0.0, horizontal: 05.0),
            child: PostWidget(
              key: ValueKey(post.id),
              post: post,
              currentUserId: currentUserId,
              sharedByUserData: sharedByUserData,
              currentProfileUserId: currentUserId,
              onView: () {},
            ),
          );
        }
      } else {
        return const SizedBox.shrink();
      }
    } catch (e) {
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
