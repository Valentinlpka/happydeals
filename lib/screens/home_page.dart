import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/combined_item.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/notification_provider.dart';
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
import 'package:happy/screens/test_notification_page.dart';
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

class _HomeState extends State<Home> with AutomaticKeepAliveClientMixin {
  late String currentUserId;
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true; // Garde la page en vie

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
      return;
    }

    await userProvider.loadUserData();
    await homeProvider.initializeFeed(
      userProvider.likedCompanies,
      userProvider.followedUsers,
    );
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
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TestNotificationPage()),
                );
              },
              icon: const Icon(Icons.notification_add),
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
            // Afficher les données existantes pendant le chargement
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData &&
                homeProvider.currentFeedItems.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
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
        key: const PageStorageKey('feed-list'),
        cacheExtent: 1000,
        padding: EdgeInsets.zero,
        addRepaintBoundaries: true,
        addAutomaticKeepAlives: true,
        controller: _scrollController,
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
            if (_isLoading) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(child: CircularProgressIndicator()),
              );
            } else {
              return const SizedBox.shrink();
            }
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

      final lastItem = homeProvider.currentFeedItems.isNotEmpty
          ? homeProvider.currentFeedItems.last
          : null;

      await homeProvider.loadMoreUnifiedFeed(
        userProvider.likedCompanies,
        userProvider.followedUsers,
        lastItem,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
      // Gestion des autres types (companies)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        child: CompanyCard(item.item as Company),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
