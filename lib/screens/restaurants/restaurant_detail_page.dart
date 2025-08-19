import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/menu_item.dart';
import 'package:happy/classes/restaurant.dart';
import 'package:happy/providers/restaurant_menu_provider.dart';
import 'package:happy/screens/restaurants/menu_customization_page.dart';
import 'package:happy/screens/unified_cart_page.dart';
import 'package:happy/services/cart_restaurant_service.dart';
import 'package:happy/widgets/cards/menu_item_card.dart';
import 'package:happy/widgets/cart_snackbar.dart';
import 'package:happy/widgets/floating_cart_button.dart';
import 'package:happy/widgets/reviews_list.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantDetailPage extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailPage({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _menuTabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Charger le menu du restaurant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestaurantMenuProvider>().loadRestaurantMenu(widget.restaurant.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (mounted && context.read<RestaurantMenuProvider>().categories.isNotEmpty) {
      _menuTabController.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar avec image de couverture
          _buildSliverAppBar(),
          
          // Informations du restaurant
          SliverToBoxAdapter(
            child: _buildRestaurantInfo(),
          ),
          
          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Menu'),
                  Tab(text: 'Infos'),
                  Tab(text: 'Avis'),
                  Tab(text: 'Photos'),
                ],
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 3,
              ),
            ),
          ),
          
          // Contenu des tabs
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMenuTab(),
                _buildInfoTab(),
                _buildReviewsTab(),
                _buildPhotosTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingCartButton(
        onPressed: () => _navigateToCart(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250.h,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image de couverture
            widget.restaurant.cover.isNotEmpty
                ? Image.network(
                    widget.restaurant.cover,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.restaurant,
                        size: 64.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.restaurant,
                      size: 64.sp,
                      color: Colors.grey[600],
                    ),
                  ),
            
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                ),
              ),
            ),
            
            // Badge statut
            Positioned(
              top: 100.h,
              right: 16.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: widget.restaurant.isOpen ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4.r,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.restaurant.isOpen ? Icons.check_circle : Icons.access_time,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      widget.restaurant.isOpen ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            // Gestion des favoris
          },
          icon: const Icon(Icons.favorite_border),
        ),
        IconButton(
          onPressed: () {
            // Partage
          },
          icon: const Icon(Icons.share),
        ),
      ],
    );
  }

  Widget _buildRestaurantInfo() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom et description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Container(
                width: 60.w,
                height: 60.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: widget.restaurant.logo.isNotEmpty
                      ? Image.network(
                          widget.restaurant.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.restaurant, size: 30.sp),
                        )
                      : Icon(Icons.restaurant, size: 30.sp),
                ),
              ),
              
              SizedBox(width: 16.w),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.restaurant.name,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.restaurant.description,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Métriques
          Row(
            children: [
              _buildMetric(
                icon: Icons.star,
                iconColor: Colors.amber,
                text: widget.restaurant.rating.toStringAsFixed(1),
                subtitle: '(${widget.restaurant.numberOfReviews} avis)',
              ),
              
              SizedBox(width: 24.w),
              
              _buildMetric(
                icon: Icons.access_time,
                iconColor: Colors.grey[600]!,
                text: '${widget.restaurant.preparationTime} min',
                subtitle: 'Préparation',
              ),
              
              if (widget.restaurant.distance != null)
                SizedBox(width: 24.w),
              
              if (widget.restaurant.distance != null)
                _buildMetric(
                  icon: Icons.location_on,
                  iconColor: Colors.grey[600]!,
                  text: '${widget.restaurant.distance!.toStringAsFixed(1)} km',
                  subtitle: 'Distance',
                ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Statut d'ouverture
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: widget.restaurant.isOpen ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: widget.restaurant.isOpen ? Colors.green[200]! : Colors.red[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.restaurant.isOpen ? Icons.check_circle : Icons.access_time,
                  color: widget.restaurant.isOpen ? Colors.green[600] : Colors.red[600],
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.restaurant.isOpen ? 'Ouvert maintenant' : 'Fermé',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: widget.restaurant.isOpen ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                      Text(
                        _getTodayHours(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: widget.restaurant.isOpen ? Colors.green[600] : Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          
         
        ],
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required Color iconColor,
    required String text,
    required String subtitle,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: iconColor,
            ),
            SizedBox(width: 4.w),
            Text(
              text,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTab() {
    return Consumer<RestaurantMenuProvider>(
      builder: (context, menuProvider, child) {
        if (menuProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (menuProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64.sp,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16.h),
                Text(
                  'Erreur lors du chargement',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  menuProvider.error!,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => menuProvider.refresh(),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (menuProvider.categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 64.sp,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16.h),
                Text(
                  'Menu non disponible',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Ce restaurant n\'a pas encore configuré son menu',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Initialiser le TabController pour les catégories
        if (!mounted) return const SizedBox.shrink();
        
        _menuTabController = TabController(
          length: menuProvider.categories.length,
          vsync: this,
        );

        return Column(
          children: [
            // Barre de recherche
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(16.w),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un plat...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14.sp,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[500],
                    size: 20.sp,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
                onChanged: (value) {
                  // Implémenter la recherche
                },
              ),
            ),

            // Promotions actives
            if (menuProvider.getActivePromotions().isNotEmpty)
              Container(
                height: 80.h,
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: menuProvider.getActivePromotions().length,
                  itemBuilder: (context, index) {
                    final promotion = menuProvider.getActivePromotions()[index];
                    return Container(
                      width: 280.w,
                      margin: EdgeInsets.only(right: 12.w, top: 8.h, bottom: 8.h),
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange[400]!, Colors.red[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            promotion.name,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            promotion.description,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Tabs des catégories
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _menuTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Theme.of(context).primaryColor,
                indicatorWeight: 2,
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.normal,
                ),
                tabs: menuProvider.categories.map((category) {
                  final itemCount = menuProvider.getItemsByCategory(category.id).length;
                  final menuCount = menuProvider.getMenusByCategory(category.id).length;
                  
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(category.name),
                        if (itemCount + menuCount > 0) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              '${itemCount + menuCount}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // Contenu des catégories
            Expanded(
              child: TabBarView(
                controller: _menuTabController,
                children: menuProvider.categories.map((category) {
                  return _buildCategoryContent(menuProvider, category);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryContent(RestaurantMenuProvider menuProvider, RestaurantMenuCategory category) {
    final items = menuProvider.getItemsByCategory(category.id);
    final menus = menuProvider.getMenusByCategory(category.id);

    if (items.isEmpty && menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 48.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 12.h),
            Text(
              'Aucun article dans cette catégorie',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: menuProvider.refresh,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // Menus en premier
          if (menus.isNotEmpty) ...[
            Text(
              'Menus',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            ...menus.map((menu) => MenuCard(
              menu: menu,
              onTap: () => _showMenuDetail(menu),
            )),
            
            if (items.isNotEmpty) ...[
              SizedBox(height: 24.h),
              Text(
                'Articles individuels',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12.h),
            ],
          ],

          // Articles individuels
          ...items.map((item) => MenuItemCard(
            item: item,
            onTap: () => _showItemDetail(item),
          )),
        ],
      ),
    );
  }

  void _showItemDetail(MenuItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildItemDetailModal(item),
    );
  }

  void _showMenuDetail(RestaurantMenu menu) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMenuDetailModal(menu),
    );
  }

  Widget _buildItemDetailModal(MenuItem item) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 20.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenu
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (item.images.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.network(
                        item.images.first,
                        width: double.infinity,
                        height: 200.h,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          height: 200.h,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.restaurant,
                            size: 64.sp,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  
                  SizedBox(height: 16.h),
                  
                  // Description
                  if (item.description.isNotEmpty) ...[
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                  
                  // Informations nutritionnelles
                  if (item.nutrition.calories > 0 || 
                      item.nutrition.allergens.isNotEmpty ||
                      item.nutrition.isVegetarian ||
                      item.nutrition.isVegan) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informations nutritionnelles',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          if (item.nutrition.calories > 0)
                            Text('${item.nutrition.calories} calories'),
                          if (item.nutrition.isVegetarian)
                            const Text('🌱 Végétarien'),
                          if (item.nutrition.isVegan)
                            const Text('🌿 Vegan'),
                          if (item.nutrition.allergens.isNotEmpty)
                            Text('Allergènes: ${item.nutrition.allergens.join(', ')}'),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ],
              ),
            ),
          ),
          
          // Footer avec prix et bouton
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Consumer<RestaurantMenuProvider>(
              builder: (context, menuProvider, child) {
                final price = menuProvider.calculateItemPrice(item);
                return Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${price.toStringAsFixed(2)}€',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        if (menuProvider.itemHasActivePromotion(item.id, item.categoryId))
                          Text(
                            'Prix promotionnel',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.red[600],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Vérifier si le restaurant est ouvert
                          if (!widget.restaurant.isOpen) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ce restaurant est actuellement fermé. Impossible de commander.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          
                          Navigator.pop(context);
                          await _addItemToCart(item);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Ajouter au panier',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuDetailModal(RestaurantMenu menu) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    'MENU',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    menu.name,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 20.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Contenu
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (menu.images.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.network(
                        menu.images.first,
                        width: double.infinity,
                        height: 200.h,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                          height: 200.h,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 64.sp,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  
                  SizedBox(height: 16.h),
                  
                  // Description
                  if (menu.description.isNotEmpty) ...[
                    Text(
                      menu.description,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                  
                  // Informations sur le menu
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Composition du menu',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '• Plat principal personnalisable\n• Accompagnements au choix\n• Boisson incluse',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.blue[600],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Footer avec prix et bouton
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Consumer<RestaurantMenuProvider>(
              builder: (context, menuProvider, child) {
                final price = menuProvider.calculateMenuPrice(menu);
                return Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${price.toStringAsFixed(2)}€',
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        Text(
                          'Menu complet',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Vérifier si le restaurant est ouvert
                          if (!widget.restaurant.isOpen) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ce restaurant est actuellement fermé. Impossible de commander.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          
                          // Personnaliser le menu
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MenuCustomizationPage(
                                menu: menu,
                                restaurantId: widget.restaurant.id,
                                restaurantName: widget.restaurant.name,
                                restaurantLogo: widget.restaurant.logo,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Personnaliser le menu',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Adresse
          _buildInfoSection(
            title: 'Adresse',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.restaurant.address.address,
                  style: TextStyle(fontSize: 14.sp),
                ),
                Text(
                  '${widget.restaurant.address.codePostal} ${widget.restaurant.address.ville}',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
            ),
            onTap: () => _launchMaps(),
          ),
          
          SizedBox(height: 24.h),
          
          // Contact
          _buildInfoSection(
            title: 'Contact',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.restaurant.phone.isNotEmpty)
                  GestureDetector(
                    onTap: () => _launchPhone(),
                    child: Text(
                      widget.restaurant.phone,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Theme.of(context).primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                if (widget.restaurant.email.isNotEmpty)
                  GestureDetector(
                    onTap: () => _launchEmail(),
                    child: Text(
                      widget.restaurant.email,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Theme.of(context).primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          SizedBox(height: 24.h),
          
          // Horaires
          _buildInfoSection(
            title: 'Horaires d\'ouverture',
            content: _buildOpeningHours(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required Widget content,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildOpeningHours() {
    const daysOfWeek = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];
    const dayKeys = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
    ];

    return Column(
      children: List.generate(7, (index) {
        final dayName = daysOfWeek[index];
        final dayKey = dayKeys[index];
        final hours = widget.restaurant.openingHours.schedule[dayKey] ?? 'fermé';
        
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black87,
                ),
              ),
              Text(
                hours == 'fermé' ? 'Fermé' : hours,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: hours == 'fermé' ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildReviewsTab() {
    return Column(
      children: [
        // Résumé des avis
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Note moyenne
              Column(
                children: [
                  Text(
                    widget.restaurant.rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < widget.restaurant.rating.round() 
                            ? Icons.star 
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 20.sp,
                      );
                    }),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${widget.restaurant.numberOfReviews} avis',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              SizedBox(width: 24.w),
              
              // Répartition des étoiles (placeholder)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Répartition des notes',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ...List.generate(5, (index) {
                      final stars = 5 - index;
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        child: Row(
                          children: [
                            Text(
                              '$stars',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.star,
                              size: 12.sp,
                              color: Colors.amber,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Container(
                                height: 4.h,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (stars == 5 ? 0.6 : 
                                               stars == 4 ? 0.3 : 
                                               stars == 3 ? 0.1 : 
                                               stars == 2 ? 0.05 : 0.02),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Liste des avis
        Expanded(
          child: ReviewsList(
            companyId: widget.restaurant.id,
            limit: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosTab() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: widget.restaurant.gallery.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64.sp,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Aucune photo disponible',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8.h,
                crossAxisSpacing: 8.w,
                childAspectRatio: 1,
              ),
              itemCount: widget.restaurant.gallery.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.network(
                    widget.restaurant.gallery[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _launchMaps() async {
    final url = 'https://maps.google.com/?q=${widget.restaurant.address.latitude},${widget.restaurant.address.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _launchPhone() async {
    final url = 'tel:${widget.restaurant.phone}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _launchEmail() async {
    final url = 'mailto:${widget.restaurant.email}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  String _getTodayHours() {
    final now = DateTime.now();
    const daysOfWeek = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday'
    ];
    
    final dayName = daysOfWeek[now.weekday - 1];
    final hours = widget.restaurant.openingHours.schedule[dayName];
    
    if (hours == null || hours == 'fermé') {
      return 'Fermé aujourd\'hui';
    }
    
    // Formater les horaires pour l'affichage
    return _formatHoursForDisplay(hours);
  }

  String _formatHoursForDisplay(String hours) {
    // Remplacer les virgules par des retours à la ligne pour les plages multiples
    return hours.replaceAll(',', '\n');
  }

  void _navigateToCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UnifiedCartPage(),
      ),
    );
  }

  Future<void> _addItemToCart(MenuItem item) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      CartSnackBar.showError(
        context: context,
        message: 'Vous devez être connecté pour ajouter des articles au panier',
      );
      return;
    }

    // Vérifier si le restaurant est ouvert
    if (!widget.restaurant.isOpen) {
      CartSnackBar.showError(
        context: context,
        message: 'Ce restaurant est actuellement fermé. Impossible d\'ajouter des articles au panier.',
      );
      return;
    }

    try {
      final cartService = Provider.of<CartRestaurantService>(context, listen: false);
      final menuProvider = Provider.of<RestaurantMenuProvider>(context, listen: false);
      
      final price = menuProvider.calculateItemPrice(item);
      
      // Créer l'item pour le panier
      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        itemId: item.id,
        name: item.name,
        description: item.description,
        unitPrice: price,
        quantity: 1,
        totalPrice: price,
        vatRate: item.vatRate, // Utiliser le taux TVA de l'item
        images: item.images,
        type: 'item',
        addedAt: DateTime.now(),
        variants: item.variants?.map((variant) {
          final defaultOption = variant.options.firstWhere(
            (option) => option.isDefault,
            orElse: () => variant.options.first,
          );
          return CartItemVariant(
            variantId: variant.id,
            name: variant.name,
            selectedOption: CartSelectedOption(
              name: defaultOption.name,
              priceModifier: defaultOption.priceModifier,
            ),
          );
        }).toList(),
      );

      await cartService.addItemToCart(
        userId: currentUser.uid,
        restaurantId: widget.restaurant.id,
        restaurantName: widget.restaurant.name,
        restaurantLogo: widget.restaurant.logo,
        item: cartItem,
      );

      CartSnackBar.showSuccess(
        context: context,
        itemName: item.name,
        price: price,
        onViewCart: () => _navigateToCart(context),
      );
    } catch (e) {
      CartSnackBar.showError(
        context: context,
        message: 'Erreur lors de l\'ajout au panier: $e',
      );
    }
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
} 