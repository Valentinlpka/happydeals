import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuantityControls extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final int minQuantity;
  final int maxQuantity;
  final bool isLoading;

  const QuantityControls({
    super.key,
    required this.quantity,
    required this.onQuantityChanged,
    this.minQuantity = 0,
    this.maxQuantity = 99,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton moins
          _buildControlButton(
            icon: Icons.remove,
            onPressed: quantity > minQuantity && !isLoading
                ? () => onQuantityChanged(quantity - 1)
                : null,
          ),
          
          // Affichage de la quantité
          Container(
            constraints: BoxConstraints(minWidth: 40.w),
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: isLoading
                ? SizedBox(
                    width: 16.w,
                    height: 16.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : Text(
                    '$quantity',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          
          // Bouton plus
          _buildControlButton(
            icon: Icons.add,
            onPressed: quantity < maxQuantity && !isLoading
                ? () => onQuantityChanged(quantity + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            icon,
            size: 18.sp,
            color: onPressed != null ? Colors.black87 : Colors.grey[400],
          ),
        ),
      ),
    );
  }
}