import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/services/like_service.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/product_card.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:provider/provider.dart';

class ModernProductDetailPage extends StatefulWidget {
  final Product product;
  const ModernProductDetailPage({super.key, required this.product});

  @override
  State<ModernProductDetailPage> createState() =>
      _ModernProductDetailPageState();
}

class _ModernProductDetailPageState extends State<ModernProductDetailPage> {
  int current = 0;
  int quantity = 1;
  ProductVariant? selectedVariant;
  Map<String, String> selectedAttributes = {};
  final ScrollController _scrollController = ScrollController();
  bool isNameExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) {
      selectedVariant = widget.product.variants[0];
      selectedAttributes = Map.from(selectedVariant!.attributes);
    }
  }



  void _updateSelectedVariant() {
    selectedVariant = widget.product.variants.firstWhere(
      (variant) => variant.attributes.entries.every(
        (entry) => selectedAttributes[entry.key] == entry.value,
      ),
      orElse: () {
        var bestMatch = widget.product.variants[0];
        var maxMatches = 0;

        for (var variant in widget.product.variants) {
          int matches = variant.attributes.entries
              .where((entry) => selectedAttributes[entry.key] == entry.value)
              .length;

          if (matches > maxMatches) {
            maxMatches = matches;
            bestMatch = variant;
          }
        }

        selectedAttributes = Map.from(bestMatch.attributes);
        return bestMatch;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProductHeader(),
                _buildMainContent(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.grey[50],
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        widget.product.name,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        StreamBuilder<bool>(
          stream: LikeMatchMarketService.isLiked(widget.product.id),
          builder: (context, snapshot) {
            final isLiked = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.black,
              ),
              onPressed: () =>
                  LikeMatchMarketService.toggleLike(widget.product.id, context),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.black),
          onPressed: _showShareBottomSheet,
        ),
      ],
    );
  }

  Widget _buildProductHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageCarousel(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: isNameExpanded ? null : 1,
                      overflow: isNameExpanded ? null : TextOverflow.ellipsis,
                    ),
                    if (widget.product.name.length > 30)
                      GestureDetector(
                        onTap: () =>
                            setState(() => isNameExpanded = !isNameExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            isNameExpanded ? 'Voir moins' : 'Voir plus',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildPriceSection()),
                    if (selectedVariant?.stock != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedVariant!.stock > 0
                              ? Colors.green.withAlpha(13)
                              : Colors.red.withAlpha(13),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selectedVariant!.stock > 0
                                  ? Icons.check_circle
                                  : Icons.error,
                              size: 16,
                              color: selectedVariant!.stock > 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              selectedVariant!.stock > 0
                                  ? 'En stock (${selectedVariant!.stock})'
                                  : 'Rupture de stock',
                              style: TextStyle(
                                color: selectedVariant!.stock > 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (widget.product.keywords.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.product.keywords.map((keyword) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          keyword,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (widget.product.variants.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildVariantSelector(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDescriptionCard(),
              if (widget.product.technicalDetails.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Caractéristiques techniques',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTechnicalDetailsCard(),
              ],
              const SizedBox(height: 16),
              const Text(
                'Informations de retrait',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildDeliveryInfoCard(),
              const SizedBox(height: 16),
              _buildSellerCard(),
              const SizedBox(height: 16),
              _buildSimilarProducts(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Text(
        widget.product.description,
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[800],
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTechnicalDetailsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
        },
        children: widget.product.technicalDetails.map((detail) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  detail.key,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(detail.value),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.product.pickupType == 'company'
                  ? Icons.store
                  : Icons.local_shipping,
              color: Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.pickupType == 'company'
                      ? 'Retrait en magasin'
                      : 'Livraison',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.product.pickupAddress},${widget.product.pickupPostalCode}, ${widget.product.pickupCity}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    final images = selectedVariant?.images ?? [];
    if (images.isEmpty) return const SizedBox();

    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: MediaQuery.of(context).size.width * 0.6,
            viewportFraction: 1,
            onPageChanged: (index, reason) => setState(() => current = index),
          ),
          items: images.map((url) {
            return Container(
              width: double.infinity,
              color: Colors.grey[50],
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // En cas d'erreur de chargement de l'image
                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.width * 0.6,
                      minHeight: 200,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Image non disponible',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  // Pendant le chargement de l'image
                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.width * 0.6,
                      minHeight: 200,
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.width * 0.6,
                      minHeight: 200,
                    ),
                    child: child,
                  );
                },
              ),
            );
          }).toList(),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: images.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: current == entry.key
                        ? Colors.blue
                        : Colors.grey.withAlpha(62),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildVariantSelector() {
    Map<String, Set<String>> attributeOptions = {};

    for (var variant in widget.product.variants) {
      variant.attributes.forEach((key, value) {
        if (!attributeOptions.containsKey(key)) {
          attributeOptions[key] = {};
        }
        attributeOptions[key]!.add(value);
      });
    }

    bool isValidCombination(Map<String, String> attributes) {
      return widget.product.variants.any((variant) {
        return attributes.entries.every(
          (entry) => variant.attributes[entry.key] == entry.value,
        );
      });
    }

    Set<String> getValidOptionsForAttribute(String attribute) {
      Set<String> validOptions = {};
      Map<String, String> tempAttributes = Map.from(selectedAttributes);

      for (var option in attributeOptions[attribute]!) {
        tempAttributes[attribute] = option;
        if (isValidCombination(tempAttributes)) {
          validOptions.add(option);
        }
      }
      return validOptions;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: attributeOptions.entries.map((entry) {
        String attribute = entry.key;
        Set<String> validOptions = getValidOptionsForAttribute(attribute);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attribute[0].toUpperCase() + attribute.substring(1).toLowerCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: validOptions.map((value) {
                  final isSelected = selectedAttributes[attribute] == value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      child: InkWell(
                        onTap: validOptions.contains(value)
                            ? () {
                                setState(() {
                                  selectedAttributes[attribute] = value;
                                  if (!isValidCombination(selectedAttributes)) {
                                    Map<String, String> newAttributes = {
                                      attribute: value
                                    };
                                    for (var variant
                                        in widget.product.variants) {
                                      if (variant.attributes[attribute] ==
                                          value) {
                                        newAttributes =
                                            Map.from(variant.attributes);
                                        break;
                                      }
                                    }
                                    selectedAttributes = newAttributes;
                                  }
                                  _updateSelectedVariant();
                                });
                              }
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.shade50
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            value,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPriceSection() {
    if (selectedVariant == null) return const SizedBox();

    final hasDiscount = selectedVariant!.discount?.isValid() ?? false;
    return Row(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasDiscount) ...[
          Text(
            '${selectedVariant!.discount!.calculateDiscountedPrice(selectedVariant!.price).toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red[500],
            ),
          ),
          Text(
            '${selectedVariant!.price.toStringAsFixed(2)} €',
            style: const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ] else
          Text(
            '${selectedVariant!.price.toStringAsFixed(2)} €',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
      ],
    );
  }

  Widget _buildSellerCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vendeur',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        CompanyInfoCard(
          name: widget.product.companyName,
          logo: widget.product.companyLogo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsEntreprise(
                    entrepriseId: widget.product.companyId,
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSimilarProducts() {
    debugPrint('🔍 Vérification des IDs du produit:');
    debugPrint('- ID: "${widget.product.id}"');
    debugPrint('- Category ID: "${widget.product.categoryId}"');
    debugPrint('- Company ID: "${widget.product.companyId}"');

    // Validation plus stricte des IDs
    if (widget.product.id.trim().isEmpty) {
      debugPrint('❌ ID du produit est vide ou contient uniquement des espaces');
      return const SizedBox();
    }

    if (widget.product.categoryId.trim().isEmpty) {
      debugPrint('❌ ID de la catégorie est vide ou contient uniquement des espaces');
      return const SizedBox();
    }

    if (widget.product.companyId.trim().isEmpty) {
      debugPrint('❌ ID de l\'entreprise est vide ou contient uniquement des espaces');
      return const SizedBox();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('type', isEqualTo: 'product')
          .where('categoryId', isEqualTo: widget.product.categoryId)
          .where('companyId', isEqualTo: widget.product.companyId)
          .where('isActive', isEqualTo: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ Erreur dans StreamBuilder: ${snapshot.error}');
          debugPrint('❌ Stack trace: ${snapshot.stackTrace}');
          return const SizedBox();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          debugPrint('ℹ️ Pas de données pour les produits similaires');
          return const SizedBox();
        }

        debugPrint('📦 Nombre de documents trouvés: ${snapshot.data!.docs.length}');

        final products = snapshot.data!.docs.map((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            
            // Vérification des données critiques
            if (!data.containsKey('id') || 
                !data.containsKey('companyId') || 
                !data.containsKey('categoryId')) {
              debugPrint('❌ Document manquant des champs requis: ${doc.id}');
              return null;
            }

            final String docId = doc.id;
            final String productId = data['id'] as String? ?? '';
            final String companyId = data['companyId'] as String? ?? '';
            final String categoryId = data['categoryId'] as String? ?? '';

            // Vérification approfondie des IDs
            if (docId.trim().isEmpty || 
                productId.trim().isEmpty || 
                companyId.trim().isEmpty || 
                categoryId.trim().isEmpty) {
              debugPrint('❌ IDs invalides dans le document ${doc.id}:');
              debugPrint('  - DocID: $docId');
              debugPrint('  - ProductID: $productId');
              debugPrint('  - CompanyID: $companyId');
              debugPrint('  - CategoryID: $categoryId');
              return null;
            }

            // Ne pas inclure le produit actuel
            if (productId == widget.product.id) {
              debugPrint('ℹ️ Produit actuel ignoré: $productId');
              return null;
            }

            debugPrint('✅ Document valide trouvé: $docId');
            return Product.fromFirestore(doc);
          } catch (e, stackTrace) {
            debugPrint('❌ Erreur lors de la conversion du produit ${doc.id}: $e');
            debugPrint('❌ Stack trace: $stackTrace');
            return null;
          }
        })
        .whereType<Product>()
            .toList();

        if (products.isEmpty) {
          debugPrint('ℹ️ Aucun produit similaire valide trouvé après filtrage');
          return const SizedBox();
        }

        debugPrint('✅ ${products.length} produits similaires valides trouvés');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Produits similaires',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 280,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return ProductCard(
                    product: products[index],
                    width: 180,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar() {
    if (selectedVariant == null) return const SizedBox();

    final hasDiscount = selectedVariant!.discount?.isValid() ?? false;
    final price = hasDiscount
        ? selectedVariant!.discount!
            .calculateDiscountedPrice(selectedVariant!.price)
        : selectedVariant!.price;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(39),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (quantity > 1) setState(() => quantity--);
                    },
                  ),
                  Text(
                    quantity.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (quantity < selectedVariant!.stock) {
                        setState(() => quantity++);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: selectedVariant!.stock > 0
                      ? () => _addToCart(quantity)
                      : null,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    selectedVariant!.stock > 0
                        ? 'Ajouter • ${(price * quantity).toStringAsFixed(2)}€'
                        : 'Rupture de stock',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(int quantity) {
    if (selectedVariant == null || selectedVariant!.stock < quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock insuffisant'),
        ),
      );
      return;
    }

    try {
      final cartService = context.read<CartService>();
      for (var i = 0; i < quantity; i++) {
        cartService.addToCart(
          widget.product,
          variantId: selectedVariant!.id,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Produit ajouté au panier'),
            ],
          ),
          action: SnackBarAction(
            label: 'VOIR LE PANIER',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CartScreen(),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _showShareBottomSheet() {
    final users = Provider.of<UserModel>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const ListTile(
                title: Text(
                  "Partager",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Partager sur mon profil'),
                onTap: () {
                  Navigator.pop(context);
                  final scaffoldContext = context;
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return ShareConfirmationDialog(
                        post: Post(
                          id: widget.product.id,
                          companyId: widget.product.sellerId,
                          timestamp: DateTime.now(),
                          type: 'product',
                          companyName: widget.product.companyName,
                          companyLogo: widget.product.companyLogo,
                        ),
                        onConfirm: (String comment) async {
                          try {
                            Navigator.of(dialogContext).pop();

                            await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(widget.product.id)
                                .update({
                              'sharesCount': FieldValue.increment(1),
                            });

                            await users.sharePost(
                              widget.product.id,
                              users.userId,
                              comment: comment,
                            );

                            if (scaffoldContext.mounted) {
                              ScaffoldMessenger.of(scaffoldContext)
                                  .showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Publication partagée avec succès!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (scaffoldContext.mounted) {
                              ScaffoldMessenger.of(scaffoldContext)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text('Erreur lors du partage: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.message_outlined),
                title: const Text('Envoyer en message'),
                onTap: () {
                  Navigator.pop(context);
                  _showConversationsList(context, users);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showConversationsList(BuildContext context, UserModel users) {
    final conversationService =
        Provider.of<ConversationService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Envoyer à...",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where(FieldPath.documentId,
                            whereIn: users.followedUsers)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (users.followedUsers.isEmpty) {
                        return const Center(
                          child: Text(
                            "Vous ne suivez aucun utilisateur",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      final usersList = snapshot.data!.docs;

                      if (usersList.isEmpty) {
                        return const Center(
                          child: Text(
                            "Aucun utilisateur trouvé",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: usersList.length,
                        itemBuilder: (context, index) {
                          final userData =
                              usersList[index].data() as Map<String, dynamic>;
                          final userId = usersList[index].id;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: userData['image_profile'] != null
                                  ? NetworkImage(userData['image_profile'])
                                  : null,
                              child: userData['image_profile'] == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                                '${userData['firstName']} ${userData['lastName']}'),
                            onTap: () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('posts')
                                    .doc(widget.product.id)
                                    .update({
                                  'sharesCount': FieldValue.increment(1),
                                });

                                await conversationService
                                    .sharePostInConversation(
                                  senderId: users.userId,
                                  receiverId: userId,
                                  post: Post(
                                    id: widget.product.id,
                                    companyId: widget.product.sellerId,
                                    timestamp: DateTime.now(),
                                    type: 'product',
                                    companyName: widget.product.companyName,
                                    companyLogo: widget.product.companyLogo,
                                  ),
                                );

                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Produit partagé avec succès')),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Erreur lors du partage: $e')),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Widget personnalisé pour les badges
class ProductBadge extends StatelessWidget {
  final String text;
  final Color color;

  const ProductBadge({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(62)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
