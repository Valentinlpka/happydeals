import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/providers/restaurant_provider.dart';
import 'package:provider/provider.dart';

class RestaurantFiltersModal extends StatefulWidget {
  const RestaurantFiltersModal({super.key});

  @override
  State<RestaurantFiltersModal> createState() => _RestaurantFiltersModalState();
}

class _RestaurantFiltersModalState extends State<RestaurantFiltersModal> {
  late RestaurantFilters _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters = context.read<RestaurantProvider>().filters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Contenu des filtres
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Catégories
                  _buildCategoriesFilter(),
                  
                  SizedBox(height: 24.h),
                  
                  // Note minimale
                  _buildRatingFilter(),
                  
                  SizedBox(height: 24.h),
                  
                  // Distance maximale
                  _buildDistanceFilter(),
                  
                  SizedBox(height: 24.h),
                  
                  // Prix
                  _buildPriceFilter(),
                  
                  SizedBox(height: 24.h),
                  
                  // Temps de préparation
                  _buildPreparationTimeFilter(),
                  
                  SizedBox(height: 24.h),
                  
                  // Options rapides
                  _buildQuickOptions(),
                ],
              ),
            ),
          ),
          
          // Boutons d'action
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
              'Filtres',
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
    );
  }

  Widget _buildCategoriesFilter() {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        if (provider.availableCategories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type de cuisine',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: provider.availableCategories.map((category) {
                final isSelected = _currentFilters.categories.contains(category);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      final newCategories = List<String>.from(_currentFilters.categories);
                      if (isSelected) {
                        newCategories.remove(category);
                      } else {
                        newCategories.add(category);
                      }
                      _currentFilters = _currentFilters.copyWith(categories: newCategories);
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20.r),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey[300]!),
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
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRatingFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note minimale',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [1.0, 2.0, 3.0, 4.0, 4.5].map((rating) {
            final isSelected = _currentFilters.minRating == rating;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentFilters = _currentFilters.copyWith(
                    minRating: isSelected ? null : rating,
                  );
                });
              },
              child: Container(
                margin: EdgeInsets.only(right: 12.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20.r),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 16.sp,
                      color: isSelected ? Colors.white : Colors.amber,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      rating.toString(),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDistanceFilter() {
    return Consumer<RestaurantProvider>(
      builder: (context, provider, child) {
        if (!provider.hasLocation) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distance maximale',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [1.0, 2.0, 5.0, 10.0, 20.0].map((distance) {
                final isSelected = _currentFilters.maxDistance == distance;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentFilters = _currentFilters.copyWith(
                        maxDistance: isSelected ? null : distance,
                      );
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 12.w),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20.r),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      '${distance.toInt()} km',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPriceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fourchette de prix',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildPriceRangeChip('€', 0, 15),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildPriceRangeChip('€€', 15, 25),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildPriceRangeChip('€€€', 25, 40),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildPriceRangeChip('€€€€', 40, double.infinity),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceRangeChip(String label, double minPrice, double maxPrice) {
    final isSelected = _currentFilters.minPrice == minPrice &&
        (_currentFilters.maxPrice == maxPrice || maxPrice.isInfinite);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _currentFilters = _currentFilters.copyWith(
              minPrice: null,
              maxPrice: null,
            );
          } else {
            _currentFilters = _currentFilters.copyWith(
              minPrice: minPrice,
              maxPrice: maxPrice.isInfinite ? null : maxPrice,
            );
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20.r),
          border: isSelected
              ? null
              : Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreparationTimeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Temps de préparation max',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [15, 30, 45, 60].map((time) {
            final isSelected = _currentFilters.maxPreparationTime == time;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentFilters = _currentFilters.copyWith(
                    maxPreparationTime: isSelected ? null : time,
                  );
                });
              },
              child: Container(
                margin: EdgeInsets.only(right: 12.w),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20.r),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  '$time min',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12.h),
        _buildSwitchTile(
          'Ouvert maintenant',
          _currentFilters.openNow,
          (value) {
            setState(() {
              _currentFilters = _currentFilters.copyWith(openNow: value);
            });
          },
        ),
        _buildSwitchTile(
          'Promotions disponibles',
          _currentFilters.hasPromotions,
          (value) {
            setState(() {
              _currentFilters = _currentFilters.copyWith(hasPromotions: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
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
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentFilters = RestaurantFilters();
                });
                context.read<RestaurantProvider>().clearFilters();
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Effacer',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                context.read<RestaurantProvider>().updateFilters(_currentFilters);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Appliquer',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 