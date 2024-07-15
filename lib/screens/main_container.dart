import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/cart_page.dart';
import 'package:happy/screens/conversation_list.dart';
import 'package:happy/screens/home_page.dart';
import 'package:happy/screens/profile_page.dart';
import 'package:happy/screens/search_page.dart';
import 'package:happy/screens/user_orders_page.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  setCurrentIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    User? userId = FirebaseAuth.instance.currentUser;
    String userUid = userId?.uid ?? "";
    String currentUserId = userUid;
    return Scaffold(
      body: [
        const Home(),
        const SearchPage(),
        const UserOrdersPage(),
        ConversationsListScreen(
          userId: currentUserId,
        ),
        const ParametrePage(),
        const CartScreen(),
      ][_currentIndex],
      bottomNavigationBar: Stack(
        children: [
          Container(
            height: 70,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.pink,
                  Colors.blue,
                ],
              ),
            ),
          ),
          SalomonBottomBar(
            itemPadding: const EdgeInsets.all(10),
            currentIndex: _currentIndex,
            onTap: (index) => setCurrentIndex(index),
            backgroundColor: Colors.transparent,
            unselectedItemColor: Colors.white,
            items: [
              /// Home
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
                icon: const Icon(Icons.message_outlined),
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
          ),
        ],
      ),
    );
  }
}
