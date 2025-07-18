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
    this.width = 200,
  });

  // Fonction utilitaire pour valider l'URL de l'image
  bool _isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final trimmedUrl = url.trim();
    if (trimmedUrl.startsWith('file:///')) return false;
    return trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://');
  }

  Widget _buildImageWithError(String? imageUrl, {bool isSmallScreen = false}) {
    if (!_isValidImageUrl(imageUrl)) {
      return Container(
        color: Colors.grey[100],
        child: Icon(
          Icons.image_outlined,
          size: isSmallScreen ? 32 : 40,
          color: Colors.grey[400],
        ),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Erreur de chargement de l\'image: $error');
        return Container(
          color: Colors.grey[100],
          child: Icon(
            Icons.image_outlined,
            size: isSmallScreen ? 32 : 40,
            color: Colors.grey[400],
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[100],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSection(
    ProductVariant variant,
    bool hasDiscount,
    double finalPrice,
    Color primaryColor,
    bool isSmallScreen,
  ) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          // Image principale
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox.expand(
              child: variant.images.isNotEmpty && _isValidImageUrl(variant.images[0])
                  ? Hero(
                      tag: 'product_${product.id}',
                      child: _buildImageWithError(variant.images[0], isSmallScreen: isSmallScreen),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: Icon(
                        Icons.image_not_supported,
                        size: isSmallScreen ? 32 : 40,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ),
          // Badge de réduction
          if (hasDiscount)
            Positioned(
              top: 8,
              left: 8,
              child:
                  _buildDiscountBadge(variant.price, finalPrice, isSmallScreen),
            ),
          // Bouton favori
          Positioned(
            top: 8,
            right: 8,
            child: _buildLikeButton(primaryColor, isSmallScreen),
          ),
          // Badge options multiples
          if (product.variants.length > 1)
            Positioned(
              bottom: 8,
              left: 8,
              child: _buildOptionsBadge(isSmallScreen),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    ProductVariant variant,
    bool hasDiscount,
    double finalPrice,
    Color primaryColor,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPriceRow(variant.price, finalPrice, hasDiscount, isSmallScreen),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 15,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          _buildCompanyInfo(isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildDiscountBadge(
    double originalPrice,
    double finalPrice,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 10,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFFF2D55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withAlpha(70),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '-${((1 - finalPrice / originalPrice) * 100).toStringAsFixed(0)}%',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isSmallScreen ? 12 : 14,
        ),
      ),
    );
  }

  Widget _buildOptionsBadge(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 10,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(26 * 8),
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26 * 2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Plusieurs options',
        style: TextStyle(
          color: Colors.white,
          fontSize: isSmallScreen ? 11 : 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    double originalPrice,
    double finalPrice,
    bool hasDiscount,
    bool isSmallScreen,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '${finalPrice.toStringAsFixed(2)} €',
          style: TextStyle(
            fontSize: isSmallScreen ? 15 : 17,
            fontWeight: FontWeight.bold,
            color: hasDiscount ? const Color(0xFFFF3B30) : Colors.black,
          ),
        ),
        if (hasDiscount) ...[
          const SizedBox(width: 4),
          Text(
            '${originalPrice.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              decoration: TextDecoration.lineThrough,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompanyInfo(bool isSmallScreen) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('companys')
          .doc(product.companyId) 
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final company = snapshot.data!.data() as Map<String, dynamic>?;
        if (company == null) return const SizedBox();

        final logoUrl = company['logo'] as String?;

        return Row(
          children: [
            if (logoUrl != null)
              Container(
                width: isSmallScreen ? 16 : 18,
                height: isSmallScreen ? 16 : 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ClipOval(
                  child: _isValidImageUrl(logoUrl)
                      ? Image.network(
                          logoUrl,
                          width: isSmallScreen ? 16 : 18,
                          height: isSmallScreen ? 16 : 18,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Erreur de chargement du logo: $error');
                            return Icon(
                              Icons.business,
                              size: isSmallScreen ? 12 : 14,
                              color: Colors.grey[400],
                            );
                          },
                        )
                      : Icon(
                          Icons.business,
                          size: isSmallScreen ? 12 : 14,
                          color: Colors.grey[400],
                        ),
                ),
              ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Expanded(
              child: Text(
                company['name'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
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

  Widget _buildLikeButton(Color primaryColor, bool isSmallScreen) {
    return StreamBuilder<bool>(
      stream: LikeMatchMarketService.isLiked(product.id),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;

        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26 * 1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: isSmallScreen ? 16 : 18,
            color: isLiked ? const Color(0xFFFF3B30) : Colors.grey[800],
          ),
        );
      },
    );
  }

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

    // Couleurs personnalisées
    const Color primaryColor = Color(0xFF6C63FF);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 360;
        final cardWidth = isSmallScreen ? constraints.maxWidth : width;

        return Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withAlpha(18),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ModernProductDetailPage(product: product),
                ),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageSection(
                    mainVariant,
                    hasDiscount,
                    finalPrice,
                    primaryColor,
                    isSmallScreen,
                  ),
                  _buildInfoSection(
                    mainVariant,
                    hasDiscount,
                    finalPrice,
                    primaryColor,
                    isSmallScreen,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
