import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/restaurant.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:happy/providers/restaurant_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/restaurants/restaurant_detail_page.dart';
import 'package:happy/screens/restaurants/restaurant_filters_modal.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/cards/restaurant_card.dart';
import 'package:happy/widgets/current_location_display.dart';
import 'package:happy/widgets/unified_location_filter.dart';
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
      _initializeLocation();
      context.read<RestaurantProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    await locationProvider.initializeLocation(userModel);
  }

  void _showLocationFilterBottomSheet() async {
    await UnifiedLocationFilter.show(
      context: context,
      onLocationChanged: () {
        setState(() {
          // La localisation a été mise à jour via le provider
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, RestaurantProvider>(
      builder: (context, locationProvider, restaurantProvider, child) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: CustomAppBar(
            title: 'Restaurants',
            align: Alignment.center,
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.location_on,
                      color: locationProvider.hasLocation 
                          ? const Color(0xFF4B88DA) 
                          : null,
                    ),
                    onPressed: _showLocationFilterBottomSheet,
                  ),
                  if (locationProvider.hasLocation)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4B88DA),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              CurrentLocationDisplay(
                onLocationChanged: () {
                  setState(() {
                    // La localisation a été mise à jour
                  });
                },
              ),
              
              // Barre de recherche et filtres
              _buildSearchAndFilters(),
              
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
        );
      },
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un restaurant ou un plat...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                          });
                          context.read<RestaurantProvider>().search('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4B88DA)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                context.read<RestaurantProvider>().search(value);
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Bouton filtres
          Consumer<RestaurantProvider>(
            builder: (context, provider, child) {
              return GestureDetector(
                onTap: () => _showFiltersModal(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: provider.filters.hasActiveFilters
                        ? const Color(0xFF4B88DA)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: provider.filters.hasActiveFilters
                          ? const Color(0xFF4B88DA)
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Icon(
                    Icons.tune,
                    color: provider.filters.hasActiveFilters
                        ? Colors.white
                        : Colors.grey[600],
                    size: 20,
                  ),
                ),
              );
            },
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
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: provider.availableCategories.length,
            itemBuilder: (context, index) {
              final category = provider.availableCategories[index];
              final isSelected = provider.filters.categories.contains(category);
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4B88DA) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF4B88DA) : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '${provider.restaurants.length} restaurant${provider.restaurants.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
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
                    const Icon(
                      Icons.sort,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getSortText(provider.sortBy),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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
    return Consumer2<RestaurantProvider, LocationProvider>(
      builder: (context, restaurantProvider, locationProvider, child) {
        // Appliquer les filtres avec la localisation quand elle change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (locationProvider.hasLocation) {
            restaurantProvider.applyFiltersWithLocation(locationProvider);
          }
        });

        if (restaurantProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (restaurantProvider.error != null) {
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
                  restaurantProvider.error!,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                ElevatedButton(
                  onPressed: () => restaurantProvider.refresh(),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        if (restaurantProvider.restaurants.isEmpty) {
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
          onRefresh: restaurantProvider.refresh,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: 16.h),
            itemCount: restaurantProvider.restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = restaurantProvider.restaurants[index];
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