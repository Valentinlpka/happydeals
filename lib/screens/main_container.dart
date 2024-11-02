import 'dart:async';

import 'package:badges/badges.dart' as badges;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_list.dart';
import 'package:happy/screens/home_page.dart';
import 'package:happy/screens/liked_post_page.dart';
import 'package:happy/screens/search_page.dart';
import 'package:happy/screens/settings_page.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/widgets/custom_bottom_bar.dart';
import 'package:provider/provider.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

final currentUserIds = FirebaseAuth.instance.currentUser?.uid ?? "";

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  late StreamSubscription<User?> _authStateSubscription;

  Stream<String> get _currentUserIdStream =>
      FirebaseAuth.instance.authStateChanges().map((user) => user?.uid ?? "");

  @override
  void initState() {
    super.initState();
    // Écouter les changements d'authentification
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      print('Auth state changed - Current user: ${user?.uid}');
      setState(() {}); // Forcer la reconstruction du widget
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  void setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _children = [
    const Home(),
    const SearchPage(),
    const LikedPostsPage(),
    ConversationsListScreen(userId: currentUserIds),
    const ParametrePage(),
    const CartScreen(),
  ];

  Widget _buildPage(String currentUserId) {
    switch (_currentIndex) {
      case 0:
        return const Home();
      case 1:
        return const SearchPage();
      case 2:
        return const LikedPostsPage();
      case 3:
        return ConversationsListScreen(userId: currentUserId);
      case 4:
        return const ParametrePage();
      case 5:
        return const CartScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomNavigationBar(String currentUserId) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Container(
      height: isIOS ? 50 + bottomPadding : 50, // Hauteur fixe comme Facebook
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink, Colors.blue],
        ),
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<Map<String, int>>(
              stream: Provider.of<ConversationService>(context, listen: false)
                  .getDetailedUnreadCount(currentUserId),
              builder: (context, snapshot) {
                final unreadCounts =
                    snapshot.data ?? {'total': 0, 'ads': 0, 'business': 0};

                return SalomonBottomBar(
                  itemPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 6,
                  ),
                  currentIndex: _currentIndex,
                  onTap: setCurrentIndex,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: Colors.white,
                  unselectedItemColor: Colors.white.withOpacity(0.7),
                  items: [
                    _buildNavItem(
                      icon: Icons.home,
                      title: "Accueil",
                    ),
                    _buildNavItem(
                      icon: Icons.search,
                      title: "Rechercher",
                    ),
                    _buildNavItem(
                      icon: Icons.favorite_border,
                      title: "Mes Likes",
                    ),
                    _buildMessageNavItem(unreadCounts),
                    _buildNavItem(
                      icon: Icons.person_outline,
                      title: "Profil",
                    ),
                    _buildNavItem(
                      icon: Icons.shopping_bag_outlined,
                      title: "Panier",
                    ),
                  ],
                );
              },
            ),
          ),
          // Ajouter le padding bottom pour iOS
          if (isIOS) SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

// Méthode helper pour créer un item de navigation standard
  SalomonBottomBarItem _buildNavItem({
    required IconData icon,
    required String title,
  }) {
    return SalomonBottomBarItem(
      icon: Icon(
        icon,
        size: 22, // Taille réduite comme Facebook
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 11, // Taille réduite comme Facebook
          fontWeight: FontWeight.w500,
        ),
      ),
      selectedColor: Colors.white,
      unselectedColor: Colors.white.withOpacity(0.7),
    );
  }

// Méthode helper pour créer l'item de navigation des messages avec badge
  SalomonBottomBarItem _buildMessageNavItem(Map<String, int> unreadCounts) {
    return SalomonBottomBarItem(
      icon: badges.Badge(
        position: badges.BadgePosition.topEnd(top: -4, end: -4),
        badgeStyle: const badges.BadgeStyle(
          padding: EdgeInsets.all(4),
          badgeColor: Colors.red,
        ),
        showBadge: unreadCounts['total']! > 0,
        badgeContent: Text(
          '${unreadCounts['total']}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: const Icon(
          Icons.message_outlined,
          size: 22,
        ),
      ),
      title: const Text(
        "Messages",
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      selectedColor: Colors.white,
      unselectedColor: Colors.white.withOpacity(0.7),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
        stream: _currentUserIdStream,
        builder: (context, snapshot) {
          final currentUserId = snapshot.data ?? "";
          print('Building MainContainer with userId: $currentUserId'); // Debug

          return SafeArea(
            child: Scaffold(
              body: IndexedStack(
                index: _currentIndex,
                children: _children,
              ),
              bottomNavigationBar: StreamBuilder<Map<String, int>>(
                stream: Provider.of<ConversationService>(context, listen: false)
                    .getDetailedUnreadCount(currentUserId),
                builder: (context, snapshot) {
                  final unreadCounts =
                      snapshot.data ?? {'total': 0, 'ads': 0, 'business': 0};

                  return CustomBottomNavBar(
                    currentIndex: _currentIndex,
                    onTap: setCurrentIndex,
                    unreadCounts: unreadCounts,
                  );
                },
              ),
            ),
          );
        });
  }
}
