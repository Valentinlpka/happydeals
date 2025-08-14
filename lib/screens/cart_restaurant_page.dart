import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/menu_item.dart';
import 'package:happy/providers/restaurant_menu_provider.dart';
import 'package:happy/screens/checkout_restaurant_page.dart';
import 'package:happy/screens/restaurants/menu_customization_page.dart';
import 'package:happy/services/cart_restaurant_service.dart';
import 'package:happy/widgets/cart_item_widget.dart';
import 'package:provider/provider.dart';

class CartRestaurantPage extends StatefulWidget {
  const CartRestaurantPage({super.key});

  @override
  State<CartRestaurantPage> createState() => _CartRestaurantPageState();
}

class _CartRestaurantPageState extends State<CartRestaurantPage> {
  @override
  void initState() {
    super.initState();
    _loadCarts();
  }

  void _loadCarts() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final cartService = Provider.of<CartRestaurantService>(context, listen: false);
    
    if (currentUser != null) {
      cartService.loadUserCarts(currentUser.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<CartRestaurantService>(
        builder: (context, cartService, child) {
          if (cartService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (cartService.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64.r,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Erreur',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    cartService.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: _loadCarts,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          if (cartService.carts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64.r,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Aucun panier',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Vos paniers apparaîtront ici',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Résumé total
              Container(
                width: double.infinity,
                margin: EdgeInsets.all(16.w),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total général',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${cartService.totalItemCount} articles',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${cartService.totalAmount.toStringAsFixed(2)}€',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Liste des paniers
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: cartService.carts.length,
                  itemBuilder: (context, index) {
                    final cart = cartService.carts.values.elementAt(index);
                    return _buildCartCard(context, cart);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartCard(BuildContext context, RestaurantCart cart) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête du restaurant
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Logo du restaurant
Container(
          width: 40.w,
          height: 40.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4.r,
                offset: Offset(0, 1.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child:  cart.restaurantLogo.isNotEmpty ? Image.network(
                    cart.restaurantLogo,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[100],
                      child: Icon(
                        Icons.restaurant,
                        size: 20.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[100],
                    child: Icon(
                      Icons.restaurant,
                      size: 20.sp,
                      color: Colors.grey[400],
                    ),
                  ),
          ),
        ),                      
                      SizedBox(width: 12.w),
                      
                      // Informations du restaurant
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cart.restaurantName,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${cart.itemCount} articles • ${cart.totalAmount.toStringAsFixed(2)}€',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8.w),
                          const Text('Vider le panier'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'clear') {
                      _showClearCartDialog(context, cart);
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Liste des items
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: cart.items.map((item) => CartItemWidget(
                item: item,
                restaurantId: cart.restaurantId,
                onEdit: item.type == 'menu' ? () => _editMenuItem(context, cart, item) : null,
                onRemove: () => _removeItem(context, cart, item),
              )).toList(),
            ),
          ),
          
          // Bouton commander
          Padding(
            padding: EdgeInsets.all(16.w),
            child: SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () => _proceedToCheckout(context, cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  'Commander • ${cart.totalAmount.toStringAsFixed(2)}€',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showClearCartDialog(BuildContext context, RestaurantCart cart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vider le panier'),
        content: Text('Êtes-vous sûr de vouloir vider le panier de ${cart.restaurantName} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CartRestaurantService>().clearCart(cart.restaurantId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
  }



  void _proceedToCheckout(BuildContext context, RestaurantCart cart) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(cart: cart),
      ),
    );
  }

  void _editMenuItem(BuildContext context, RestaurantCart cart, CartItem item) async {
    if (item.type != 'menu') return;

    try {
      // Récupérer le menu original depuis le provider
      final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
      
      // Charger le menu du restaurant si ce n'est pas déjà fait
      await menuProvider.loadRestaurantMenu(cart.restaurantId);
      
      // Chercher le menu correspondant à l'article
      RestaurantMenu? originalMenu;
      for (final category in menuProvider.categories) {
        final menus = menuProvider.getMenusByCategory(category.id);
        for (final menu in menus) {
          if (menu.id == item.itemId) {
            originalMenu = menu;
            break;
          }
        }
        if (originalMenu != null) break;
      }

      if (originalMenu == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu original introuvable'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Naviguer vers la page de personnalisation en mode édition
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MenuCustomizationPage(
            menu: originalMenu!,
            restaurantId: cart.restaurantId,
            restaurantName: cart.restaurantName,
            restaurantLogo: cart.restaurantLogo,
            existingItem: item,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement du menu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeItem(BuildContext context, RestaurantCart cart, CartItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'article'),
        content: Text('Voulez-vous supprimer "${item.name}" de votre panier ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<CartRestaurantService>().removeItemFromCart(
                  restaurantId: cart.restaurantId,
                  itemId: item.id,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${item.name} supprimé du panier'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de la suppression: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}