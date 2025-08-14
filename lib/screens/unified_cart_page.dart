import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/screens/cart_restaurant_page.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/services/cart_restaurant_service.dart';
import 'package:happy/services/cart_service.dart';
import 'package:provider/provider.dart';

class UnifiedCartPage extends StatefulWidget {
  const UnifiedCartPage({super.key});

  @override
  State<UnifiedCartPage> createState() => _UnifiedCartPageState();
}

class _UnifiedCartPageState extends State<UnifiedCartPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Déclencher un rebuild quand l'onglet change pour mettre à jour l'AppBar
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mes Paniers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Bouton "Tout vider" pour les paniers de restaurants
          Consumer<CartRestaurantService>(
            builder: (context, cartService, child) {
              // Afficher le bouton seulement si on est sur l'onglet restaurants et qu'il y a des paniers
              if (_tabController.index == 1 && cartService.carts.isNotEmpty) {
                return TextButton(
                  onPressed: () => _showClearAllDialog(context),
                  child: const Text(
                    'Tout vider',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3.0,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.normal,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined),
                  SizedBox(width: 8.w),
                  const Text('Boutiques'),
                  Consumer<CartService>(
                    builder: (context, cartService, child) {
                      final itemCount = cartService.activeCarts
                          .fold<int>(0, (sum, cart) => sum + cart.items.length);
                      if (itemCount > 0) {
                        return Container(
                          margin: EdgeInsets.only(left: 4.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            '$itemCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant_outlined),
                  SizedBox(width: 8.w),
                  const Text('Restaurants'),
                  Consumer<CartRestaurantService>(
                    builder: (context, cartService, child) {
                      final itemCount = cartService.totalItemCount;
                      if (itemCount > 0) {
                        return Container(
                          margin: EdgeInsets.only(left: 4.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            '$itemCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ShopCartTab(),
          _RestaurantCartTab(),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider tous les paniers'),
        content: const Text('Êtes-vous sûr de vouloir vider tous vos paniers de restaurant ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CartRestaurantService>().clearAllCarts();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Tout vider'),
          ),
        ],
      ),
    );
  }
}

class _ShopCartTab extends StatelessWidget {
  const _ShopCartTab();

  @override
  Widget build(BuildContext context) {
    return const CartScreen();
  }
}

class _RestaurantCartTab extends StatelessWidget {
  const _RestaurantCartTab();

  @override
  Widget build(BuildContext context) {
    return const CartRestaurantPage();
  }
}