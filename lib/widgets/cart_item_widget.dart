import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/services/cart_restaurant_service.dart';
import 'package:happy/widgets/quantity_controls.dart';
import 'package:provider/provider.dart';

class CartItemWidget extends StatefulWidget {
  final CartItem item;
  final String restaurantId;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final bool showControls;

  const CartItemWidget({
    super.key,
    required this.item,
    required this.restaurantId,
    this.onEdit,
    this.onRemove,
    this.showControls = true,
  });

  @override
  State<CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        children: [
          // Contenu principal
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // En-tête avec image, nom et prix
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    _buildItemImage(),
                    
                    SizedBox(width: 12.w),
                    
                    // Nom et badge
                    Expanded(
                      child: _buildItemHeader(),
                    ),
                    
                    SizedBox(width: 8.w),
                    
                    // Prix et contrôles
                    _buildPriceAndControls(),
                  ],
                ),
                

                
                // Détails des menus ou variantes
                if (widget.item.type == 'menu') ...[
                  SizedBox(height: 12.h),
                  _buildMenuInfo(),
                ] else if (widget.item.type == 'item' && widget.item.variants?.isNotEmpty == true) ...[
                  SizedBox(height: 8.h),
                  _buildVariantsInfo(),
                ],
              ],
            ),
          ),
          
          // Actions (si c'est un menu personnalisé et que les contrôles sont activés)
          if (widget.showControls && widget.item.type == 'menu' && widget.onEdit != null)
            _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildItemImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: widget.item.images.isNotEmpty
          ? Image.network(
              widget.item.images.first,
              width: 60.w,
              height: 60.h,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildDefaultImage(),
            )
          : _buildDefaultImage(),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      width: 60.w,
      height: 60.h,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(
        widget.item.type == 'menu' ? Icons.restaurant_menu : Icons.restaurant,
        size: 24.sp,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildItemHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Badge et nom
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
           
            Expanded(
              child: Text(
                widget.item.name,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildVariantsInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                size: 12.sp,
                color: Colors.grey[600],
              ),
              SizedBox(width: 4.w),
              Text(
                'Personnalisation',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 4.h,
            children: widget.item.variants!.map((variant) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${variant.name}: ${variant.selectedOption.name}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête "Composition"
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 14.sp,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(width: 6.w),
              Text(
                'Composition du menu',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8.h),
          
          // Article principal
          if (widget.item.mainItem != null) ...[
            _buildMenuSection(
              title: 'Plat principal',
              itemName: widget.item.mainItem!.name,
              variants: widget.item.mainItem!.variants,
              icon: Icons.restaurant,
            ),
            
            if (widget.item.options?.isNotEmpty == true)
              SizedBox(height: 12.h),
          ],
          
          // Options/Accompagnements
          if (widget.item.options?.isNotEmpty == true) ...[
            ...widget.item.options!.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              
              return Column(
                children: [
                  _buildMenuSection(
                    title: option.templateName,
                    itemName: option.item.name,
                    variants: option.item.variants,
                    icon: Icons.add_circle_outline,
                  ),
                  if (index < widget.item.options!.length - 1)
                    SizedBox(height: 8.h),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required String title,
    required String itemName,
    List<CartItemVariant>? variants,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre de la section
        Row(
          children: [
            Icon(
              icon,
              size: 12.sp,
              color: Colors.grey[600],
            ),
            SizedBox(width: 4.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 4.h),
        
        // Nom de l'article
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 0.5,
            ),
          ),
          child: Text(
            itemName,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        
        // Variantes si présentes
        if (variants?.isNotEmpty == true) ...[
          SizedBox(height: 6.h),
          Wrap(
            spacing: 4.w,
            runSpacing: 4.h,
            children: variants!.map((variant) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(
                    color: Colors.blue[200]!,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${variant.name}: ${variant.selectedOption.name}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceAndControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Prix
        Text(
          '${widget.item.totalPrice.toStringAsFixed(2)}€',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        
        if (widget.item.quantity > 1) ...[
          Text(
            '${widget.item.unitPrice.toStringAsFixed(2)}€ × ${widget.item.quantity}',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
        
        SizedBox(height: 8.h),
        
        // Contrôles de quantité (si activés)
        if (widget.showControls)
          QuantityControls(
            quantity: widget.item.quantity,
            isLoading: _isUpdating,
            onQuantityChanged: _handleQuantityChange,
          )
        else
          Text(
            'Quantité: ${widget.item.quantity}',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      decoration: BoxDecoration(
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
            child: TextButton.icon(
              onPressed: widget.onEdit,
              icon: Icon(
                Icons.edit,
                size: 16.sp,
                color: Theme.of(context).primaryColor,
              ),
              label: Text(
                'Modifier',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 40.h,
            color: Colors.grey[200],
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: widget.onRemove,
              icon: Icon(
                Icons.delete_outline,
                size: 16.sp,
                color: Colors.red[600],
              ),
              label: Text(
                'Supprimer',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.red[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleQuantityChange(int newQuantity) async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final cartService = Provider.of<CartRestaurantService>(context, listen: false);
      await cartService.updateItemQuantity(
        restaurantId: widget.restaurantId,
        itemId: widget.item.id,
        newQuantity: newQuantity,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }
}