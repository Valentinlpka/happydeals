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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink, Colors.blue],
        ),
      ),
      child: StreamBuilder<Map<String, int>>(
          stream: Provider.of<ConversationService>(context, listen: false)
              .getDetailedUnreadCount(currentUserId),
          builder: (context, snapshot) {
            final unreadCounts =
                snapshot.data ?? {'total': 0, 'ads': 0, 'business': 0};

            return SalomonBottomBar(
              itemPadding: const EdgeInsets.all(10),
              currentIndex: _currentIndex,
              onTap: setCurrentIndex,
              backgroundColor: Colors.transparent,
              unselectedItemColor: Colors.white,
              items: [
                SalomonBottomBarItem(
                  icon: const Icon(Icons.home),
                  title: const Text("Accueil"),
                  selectedColor: Colors.white,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.search),
                  title: const Text("Rechercher"),
                  selectedColor: Colors.white,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.favorite_border),
                  title: const Text("Mes Likes"),
                  selectedColor: Colors.white,
                ),
                SalomonBottomBarItem(
                  icon: badges.Badge(
                    badgeStyle: const badges.BadgeStyle(
                      padding: EdgeInsets.all(6),
                      badgeColor: Colors.red, // Plus visible pour les messages
                    ),
                    showBadge: unreadCounts['total']! > 0,
                    badgeContent: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${unreadCounts['total']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        if (unreadCounts['ads']! > 0 &&
                            unreadCounts['business']! > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 2),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    child: const Icon(Icons.message_outlined),
                  ),
                  title: const Text("Messages"),
                  selectedColor: Colors.white,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.person_outline),
                  title: const Text("Profil"),
                  selectedColor: Colors.white,
                ),
                SalomonBottomBarItem(
                  icon: const Icon(Icons.shopping_bag_outlined),
                  title: const Text("Panier"),
                  selectedColor: Colors.white,
                ),
              ],
            );
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _currentUserIdStream,
      builder: (context, snapshot) {
        final currentUserId = snapshot.data ?? "";
        print('Building MainContainer with userId: $currentUserId'); // Debug

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: [
              const Home(),
              const SearchPage(),
              const LikedPostsPage(),
              ConversationsListScreen(userId: currentUserId),
              const ParametrePage(),
              const CartScreen(),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigationBar(currentUserId),
        );
      },
    );
  }
}
