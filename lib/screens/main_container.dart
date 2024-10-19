import 'package:badges/badges.dart' as badges;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_list.dart';
import 'package:happy/screens/home_page.dart';
import 'package:happy/screens/liked_post_page.dart';
import 'package:happy/screens/profile.dart';
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
  late final String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
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

  Widget _buildPage() {
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
        return Profile(userId: currentUserId);
      case 5:
        return const CartScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink, Colors.blue],
        ),
      ),
      child: StreamBuilder<int>(
          stream: Provider.of<ConversationService>(context, listen: false)
              .getTotalUnreadCount(currentUserId),
          builder: (context, snapshot) {
            int unreadCount = snapshot.data ?? 0;
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
                    badgeStyle:
                        const badges.BadgeStyle(padding: EdgeInsets.all(6)),
                    showBadge: unreadCount > 0,
                    badgeContent: Text('$unreadCount',
                        style: const TextStyle(color: Colors.white)),
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _children,
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}
