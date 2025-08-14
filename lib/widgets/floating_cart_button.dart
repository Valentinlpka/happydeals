import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/services/cart_restaurant_service.dart';
import 'package:provider/provider.dart';

class FloatingCartButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FloatingCartButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartRestaurantService>(
      builder: (context, cartService, child) {
        final totalItemCount = cartService.totalItemCount;
        final totalAmount = cartService.totalAmount;

        if (totalItemCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.all(16.w),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(25.r),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(25.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25.r),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 12.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                        if (totalItemCount > 0)
                          Positioned(
                            right: -8.w,
                            top: -8.h,
                            child: Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: BoxDecoration(
                                color: Colors.red[500],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 20.w,
                                minHeight: 20.h,
                              ),
                              child: Text(
                                totalItemCount > 99 ? '99+' : totalItemCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    SizedBox(width: 12.w),
                    
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Voir le panier',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${totalAmount.toStringAsFixed(2)}€',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(width: 8.w),
                    
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16.sp,
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