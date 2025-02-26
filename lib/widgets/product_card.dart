import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/services/like_service.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final double width;

  const ProductCard({
    super.key,
    required this.product,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    final mainVariant = product.variants.firstOrNull;
    if (mainVariant == null) return const SizedBox();

    final activeDiscount = mainVariant.discount?.isValid() ?? false
        ? mainVariant.discount
        : product.discount?.isValid() ?? false
            ? product.discount
            : null;

    final hasDiscount = activeDiscount != null;
    final finalPrice = hasDiscount
        ? activeDiscount.calculateDiscountedPrice(mainVariant.price)
        : mainVariant.price;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ModernProductDetailPage(product: product),
        ),
      ),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildImageSection(mainVariant, hasDiscount, finalPrice),
            _buildInfoSection(mainVariant, hasDiscount, finalPrice),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(
    ProductVariant variant,
    bool hasDiscount,
    double finalPrice,
  ) {
    return Stack(
      children: [
        // Image principale
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: AspectRatio(
            aspectRatio: 1,
            child: variant.images.isNotEmpty
                ? Hero(
                    tag: 'product_${product.id}',
                    child: Image.network(
                      variant.images[0],
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(
                    color: Colors.grey[100],
                    child: const Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
        // Badge de réduction
        if (hasDiscount)
          Positioned(
            top: 8,
            left: 8,
            child: _buildDiscountBadge(variant.price, finalPrice),
          ),
        // Bouton favori
        Positioned(
          top: 8,
          right: 8,
          child: _buildLikeButton(),
        ),
        // Badge options multiples
        if (product.variants.length > 1)
          Positioned(
            bottom: 8,
            left: 8,
            child: _buildOptionsBadge(),
          ),
      ],
    );
  }

  Widget _buildInfoSection(
    ProductVariant variant,
    bool hasDiscount,
    double finalPrice,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        spacing: 5,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPriceRow(variant.price, finalPrice, hasDiscount),
          const SizedBox(height: 4),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          _buildCompanyInfo(),
        ],
      ),
    );
  }

  Widget _buildDiscountBadge(double originalPrice, double finalPrice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '-${((1 - finalPrice / originalPrice) * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildOptionsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Plusieurs options',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriceRow(
      double originalPrice, double finalPrice, bool hasDiscount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${finalPrice.toStringAsFixed(2)} €',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: hasDiscount ? Colors.red : Colors.black,
          ),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: 4),
          Text(
            '${originalPrice.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 11,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompanyInfo() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('companys')
          .doc(product.sellerId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final company = snapshot.data!.data() as Map<String, dynamic>?;
        if (company == null) return const SizedBox();

        return Row(
          children: [
            if (company['logo'] != null)
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!),
                  image: DecorationImage(
                    image: NetworkImage(company['logo']),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                company['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLikeButton() {
    return StreamBuilder<bool>(
      stream: LikeService.isLiked(product.id),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => LikeService.toggleLike(product.id, context),
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isLiked ? Colors.red : Colors.grey[800],
              ),
            ),
          ),
        );
      },
    );
  }
}
