import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/restaurant.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback? onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10.r,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image de couverture avec logo et badges
                _buildImageHeader(),
                
                // Informations du restaurant
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom et description
                      _buildRestaurantInfo(),
                      
                      SizedBox(height: 8.h),
                      
                      // Tags de cuisine
                      _buildTags(),
                      
                      SizedBox(height: 12.h),
                      
                      // Rating, temps, distance et prix
                      _buildMetrics(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageHeader() {
    return Stack(
      children: [
        // Image de couverture
        ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.r),
            topRight: Radius.circular(16.r),
          ),
          child: SizedBox(
            height: 160.h,
            width: double.infinity,
            child: restaurant.cover.isNotEmpty
                ? Image.network(
                    restaurant.cover,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.restaurant,
                        size: 48.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  )
                : Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.restaurant,
                      size: 48.sp,
                      color: Colors.grey[600],
                    ),
                  ),
          ),
        ),
        
        // Logo du restaurant
        Positioned(
          bottom: -20.h,
          left: 16.w,
          child: Container(
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
              child: restaurant.logo.isNotEmpty
                  ? Image.network(
                      restaurant.logo,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.restaurant, size: 30.sp),
                    )
                  : Icon(Icons.restaurant, size: 30.sp),
            ),
          ),
        ),
        
        // Badge ouvert/fermé
        Positioned(
          top: 12.h,
          right: 12.w,
          child: _buildStatusBadge(),
        ),
        
        // Badge promotion (si applicable)
        if (_hasActivePromotion())
          Positioned(
            top: 12.h,
            left: 12.w,
            child: _buildPromotionBadge(),
          ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final isOpen = restaurant.isOpen;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4.r,
            offset: Offset(0, 1.h),
          ),
        ],
      ),
      child: Text(
        isOpen ? 'Ouvert' : 'Fermé',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPromotionBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4.r,
            offset: Offset(0, 1.h),
          ),
        ],
      ),
      child: Text(
        'PROMO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                restaurant.name,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            // Heart icon for favorites
            Icon(
              Icons.favorite_border,
              size: 20.sp,
              color: Colors.grey[400],
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          restaurant.description,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[600],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 6.w,
      runSpacing: 4.h,
      children: restaurant.tags.take(3).map((tag) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetrics() {
    return Row(
      children: [
        // Rating
        _buildMetricItem(
          icon: Icons.star,
          iconColor: Colors.amber,
          text: '${restaurant.rating.toStringAsFixed(1)} (${restaurant.numberOfReviews})',
        ),
        
        SizedBox(width: 16.w),
        
        // Temps de préparation
        _buildMetricItem(
          icon: Icons.access_time,
          iconColor: Colors.grey[600]!,
          text: '${restaurant.preparationTime} min',
        ),
        
        SizedBox(width: 16.w),
        
        // Distance (si disponible)
        if (restaurant.distance != null)
          _buildMetricItem(
            icon: Icons.location_on,
            iconColor: Colors.grey[600]!,
            text: '${restaurant.distance!.toStringAsFixed(1)} km',
          ),
        
        const Spacer(),
        
        // Prix moyen
        Text(
          '€${restaurant.averageOrderValue.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.green[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16.sp,
          color: iconColor,
        ),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _hasActivePromotion() {
    // Pour l'instant, retourner false
    // Cette logique sera implémentée quand on aura les promotions
    return false;
  }
} 