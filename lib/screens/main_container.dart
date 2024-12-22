import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_list.dart';
import 'package:happy/screens/home_page.dart';
import 'package:happy/screens/marketplace/ad_list_page.dart';
import 'package:happy/screens/search_page.dart';
import 'package:happy/screens/settings_page.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/widgets/custom_bottom_bar.dart';
import 'package:provider/provider.dart';

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
    const AdListPage(),
    ConversationsListScreen(userId: currentUserIds),
    const ParametrePage(),
    const CartScreen(),
  ];

// Méthode helper pour créer un item de navigation standard

// Méthode helper pour créer l'item de navigation des messages avec badge

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _currentUserIdStream,
      builder: (context, snapshot) {
        final currentUserId = snapshot.data ?? "";
        return Scaffold(
          extendBody: true,
          extendBodyBehindAppBar: true, // Ajoutez cette ligne
          body: Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _currentIndex,
                children: _children,
              ),
            ),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.pink, Colors.blue],
              ),
            ),
            child: SafeArea(
              child: StreamBuilder<Map<String, int>>(
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
          ),
        );
      },
    );
  }
}
