import 'package:flutter/material.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

import '../screens/home_page.dart';

class HomeWithBottomNav extends StatefulWidget {
  const HomeWithBottomNav({Key? key}) : super(key: key);

  @override
  State<HomeWithBottomNav> createState() => _HomeWithBottomNavState();
}

class _HomeWithBottomNavState extends State<HomeWithBottomNav> {
  @override
  Widget build(BuildContext context) {
    int currentIndex = 0;
    setCurrentIndex(int index) {
      setState(() {
        currentIndex = index;
      });
    }

    return Scaffold(
      body: const Home(),
      bottomNavigationBar: Stack(
        children: [
          Container(
            height: 86,
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
            currentIndex: currentIndex,
            onTap: (index) => setCurrentIndex(index),
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
                icon: const Icon(Icons.notifications_on_outlined),
                title: const Text("Notifications"),
                selectedColor: Colors.white,
              ),
              SalomonBottomBarItem(
                icon: const Icon(Icons.person_outline),
                title: const Text("Profil"),
                selectedColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
