import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/restaurant.dart';
import 'package:happy/providers/restaurant_provider.dart';
import 'package:happy/screens/restaurants/restaurant_detail_page.dart';
import 'package:happy/screens/restaurants/restaurant_filters_modal.dart';
import 'package:happy/widgets/cards/restaurant_card.dart';
import 'package:provider/provider.dart';

class RestaurantsPage extends StatefulWidget {
  const RestaurantsPage({super.key});

  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RestaurantProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header avec recherche et filtres
            _buildHeader(),
            
            // Catégories horizontales
            _buildCategoriesSection(),
            
            // Informations de tri et nombre de résultats
            _buildResultsInfo(),
            
            // Liste des restaurants
            Expanded(
              child: _buildRestaurantsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et localisation
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restaurants',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Consumer<RestaurantProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLocationLoading) {
                          return Row(
                            children: [
                              SizedBox(
                                width: 12.w,
                                height: 12.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Localisation...',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          );
                        }
                        
                        if (provider.hasLocation) {
                          return Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16.sp,
                                color: Colors.green,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Près de vous',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          );
                        }
                        
                        return GestureDetector(
                          onTap: () => provider.initialize(),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 16.sp,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'Activer la localisation',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.orange,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Menu utilisateur
              CircleAvatar(
                radius: 20.r,
                backgroundColor: Colors.grey[200],
                child: Icon(
                  Icons.person,
                  size: 20.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Barre de recherche et filtres
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un restaurant ou un plat...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey[500],
                        size: 20.sp,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    onChanged: (value) {
                      context.read<RestaurantProvider>().search(value);
                    },
                  ),
                ),
              ),
              
              SizedBox(width: 12.w),
              
              // Bouton filtres
              Consumer<RestaurantProvider>(
                builder: (context, provider, child) {
                  return GestureDetector(
                    onTap: () => _showFiltersModal(context),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: provider.filters.hasActiveFilters
                            ? Theme.of(context).primaryColor
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.tune,
                        color: provider.filters.hasActiveFilters
                            ? Colors.white
                            : Colors.grey[600],
                        size: 20.sp,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        if (provider.availableCategories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 50.h,
          color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: provider.availableCategories.length,
            itemBuilder: (context, index) {
              final category = provider.availableCategories[index];
              final isSelected = provider.filters.categories.contains(category);
              
              return GestureDetector(
                onTap: () {
                  final newCategories = List<String>.from(provider.filters.categories);
                  if (isSelected) {
                    newCategories.remove(category);
                  } else {
                    newCategories.add(category);
                  }
                  
                  provider.updateFilters(
                    provider.filters.copyWith(categories: newCategories),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(right: 12.w, top: 8.h, bottom: 8.h),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildResultsInfo() {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        return Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              Text(
                '${provider.restaurants.length} restaurant${provider.restaurants.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const Spacer(),
              
              // Bouton de tri
              GestureDetector(
                onTap: () => _showSortModal(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sort,
                      size: 16.sp,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _getSortText(provider.sortBy),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildRestaurantsList() {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.error != null) {
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
                  provider.error!,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => provider.refresh(),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (provider.restaurants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 64.sp,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16.h),
                Text(
                  'Aucun restaurant trouvé',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Essayez de modifier vos filtres ou votre recherche',
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

        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: 16.h),
            itemCount: provider.restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = provider.restaurants[index];
              return RestaurantCard(
                restaurant: restaurant,
                onTap: () => _navigateToRestaurantDetail(restaurant),
              );
            },
          ),
        );
      },
    );
  }

  void _navigateToRestaurantDetail(Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailPage(restaurant: restaurant),
      ),
    );
  }

  void _showFiltersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RestaurantFiltersModal(),
    );
  }

  void _showSortModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trier par',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            ...RestaurantSortBy.values.map((sortBy) {
              return Consumer<RestaurantProvider>(
                builder: (context, provider, child) {
                  final isSelected = provider.sortBy == sortBy;
                  return ListTile(
                    title: Text(_getSortText(sortBy)),
                    trailing: isSelected
                        ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                        : null,
                    onTap: () {
                      provider.updateSorting(sortBy);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getSortText(RestaurantSortBy sortBy) {
    switch (sortBy) {
      case RestaurantSortBy.distance:
        return 'Distance';
      case RestaurantSortBy.rating:
        return 'Note';
      case RestaurantSortBy.preparationTime:
        return 'Temps de préparation';
      case RestaurantSortBy.averagePrice:
        return 'Prix';
      case RestaurantSortBy.popularity:
        return 'Popularité';
    }
  }
} 