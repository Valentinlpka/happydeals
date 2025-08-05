import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/menu_item.dart';
import 'package:happy/providers/restaurant_menu_provider.dart';
import 'package:provider/provider.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback? onTap;

  const MenuItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RestaurantMenuProvider>(
      builder: (context, menuProvider, child) {
        final originalPrice = item.basePrice;
        final currentPrice = menuProvider.calculateItemPrice(item);
        final hasPromotion = menuProvider.itemHasActivePromotion(item.id, item.categoryId);
        
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contenu textuel
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nom et badges
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              // Badges nutrition
                              if (item.nutrition.isVegetarian)
                                _buildNutritionBadge(
                                  icon: Icons.eco,
                                  color: Colors.green,
                                  tooltip: 'Végétarien',
                                ),
                              if (item.nutrition.isVegan)
                                _buildNutritionBadge(
                                  icon: Icons.nature,
                                  color: Colors.green[700]!,
                                  tooltip: 'Vegan',
                                ),
                            ],
                          ),
                          
                          SizedBox(height: 4.h),
                          
                          // Description
                          if (item.description.isNotEmpty)
                            Text(
                              item.description,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          
                          SizedBox(height: 8.h),
                          
                          // Prix et promotion
                          Row(
                            children: [
                              if (hasPromotion && currentPrice < originalPrice) ...[
                                // Prix barré
                                Text(
                                  '${originalPrice.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                // Prix actuel
                                Text(
                                  '${currentPrice.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[600],
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                // Badge promo
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Colors.red[600],
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    'PROMO',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Prix normal
                                Text(
                                  '${currentPrice.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                              
                              const Spacer(),
                              
                              // Temps de préparation si > 0
                              if (item.preparationTime > 0) ...[
                                Icon(
                                  Icons.access_time,
                                  size: 14.sp,
                                  color: Colors.grey[500],
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${item.preparationTime} min',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          // Calories si disponibles
                          if (item.nutrition.calories > 0)
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(
                                '${item.nutrition.calories} cal',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 12.w),
                    
                    // Image et bouton d'ajout
                    Stack(
                      children: [
                        // Image de l'article
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: SizedBox(
                            width: 80.w,
                            height: 80.h,
                            child: item.images.isNotEmpty
                                ? Image.network(
                                    item.images.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.restaurant,
                                        size: 32.sp,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.restaurant,
                                      size: 32.sp,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                          ),
                        ),
                        
                        // Bouton d'ajout
                        Positioned(
                          bottom: -4.h,
                          right: -4.w,
                          child: Container(
                            width: 28.w,
                            height: 28.h,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4.r,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add,
                              size: 18.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutritionBadge({
    required IconData icon,
    required Color color,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: EdgeInsets.only(left: 4.w),
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 12.sp,
          color: color,
        ),
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  final RestaurantMenu menu;
  final VoidCallback? onTap;

  const MenuCard({
    super.key,
    required this.menu,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RestaurantMenuProvider>(
      builder: (context, menuProvider, child) {
        final originalPrice = menu.basePrice;
        final currentPrice = menuProvider.calculateMenuPrice(menu);
        final hasPromotion = menuProvider.menuHasActivePromotion(menu.id);
        
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contenu textuel
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge MENU + Nom
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'MENU',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  menu.name,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 6.h),
                          
                          // Description
                          if (menu.description.isNotEmpty)
                            Text(
                              menu.description,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          
                          SizedBox(height: 8.h),
                          
                          // Prix
                          Row(
                            children: [
                              if (hasPromotion && currentPrice < originalPrice) ...[
                                Text(
                                  '${originalPrice.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[500],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  '${currentPrice.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[600],
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Colors.red[600],
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    'PROMO',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  '${currentPrice.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                              
                              const Spacer(),
                              
                              // Indicateur d'économie pour les menus
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'ÉCONOMIQUE',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 12.w),
                    
                    // Image et bouton d'ajout
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: SizedBox(
                            width: 80.w,
                            height: 80.h,
                            child: menu.images.isNotEmpty
                                ? Image.network(
                                    menu.images.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.restaurant_menu,
                                        size: 32.sp,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.restaurant_menu,
                                      size: 32.sp,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                          ),
                        ),
                        
                        Positioned(
                          bottom: -4.h,
                          right: -4.w,
                          child: Container(
                            width: 28.w,
                            height: 28.h,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4.r,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add,
                              size: 18.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 