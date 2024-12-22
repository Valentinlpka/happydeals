import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/services/cart_service.dart';
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
  late Future<Map<String, dynamic>> companyFuture;

  @override
  void initState() {
    super.initState();
    companyFuture = _loadCompanyData();
    if (widget.product.variants.isNotEmpty) {
      selectedVariant = widget.product.variants[0];
      selectedAttributes = Map.from(selectedVariant!.attributes);
    }
  }

  Future<Map<String, dynamic>> _loadCompanyData() async {
    final doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(widget.product.sellerId)
        .get();
    return doc.data() ?? {};
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
    bool isFavorite =
        context.watch<UserModel>().likedPosts.contains(widget.product.id);
    final hasDiscount = selectedVariant?.discount?.isValid() ?? false;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isFavorite),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageCarousel(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildVariantSelector(),
                        if (selectedVariant != null)
                          _buildPriceSection(hasDiscount),
                        const SizedBox(height: 16),
                        _buildProductDetails(),
                        _buildSellerInfo(),
                        _buildSimilarProducts(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomSheet(),
    );
  }

  Widget _buildSliverAppBar(bool isFavorite) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.black,
          ),
          onPressed: () {
            // Gérer les favoris
          },
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.black),
          onPressed: () {
            // Gérer le partage
          },
        ),
      ],
    );
  }

  Widget _buildImageCarousel() {
    final images = selectedVariant?.images ?? [];
    if (images.isEmpty) return const SizedBox();

    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 350,
            viewportFraction: 1,
            onPageChanged: (index, reason) => setState(() => current = index),
          ),
          items: images.map((url) {
            return Container(
              width: double.infinity,
              color: Colors.grey[100],
              child: Image.network(url, fit: BoxFit.contain),
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
                        : Colors.grey.withOpacity(0.5),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                attribute,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              children: validOptions.map((value) {
                final isSelected = selectedAttributes[attribute] == value;
                return ChoiceChip(
                  label: Text(value),
                  selected: isSelected,
                  onSelected: validOptions.contains(value)
                      ? (bool selected) {
                          if (selected) {
                            setState(() {
                              selectedAttributes[attribute] = value;

                              if (!isValidCombination(selectedAttributes)) {
                                Map<String, String> newAttributes = {
                                  attribute: value
                                };
                                for (var variant in widget.product.variants) {
                                  if (variant.attributes[attribute] == value) {
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
                        }
                      : null, // Si l'option n'est pas valide, on désactive le chip
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPriceSection(bool hasDiscount) {
    if (selectedVariant == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDiscount) ...[
          Text(
            '${selectedVariant!.price.toStringAsFixed(2)}€',
            style: const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          Text(
            '${selectedVariant!.discount!.calculateDiscountedPrice(selectedVariant!.price).toStringAsFixed(2)}€',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ] else
          Text(
            '${selectedVariant!.price.toStringAsFixed(2)}€',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
      ],
    );
  }

  Widget _buildProductDetails() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(widget.product.description),
            if (selectedVariant != null) ...[
              const Divider(height: 32),
              Text(
                'Stock disponible: ${selectedVariant!.stock}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSellerInfo() {
    return FutureBuilder<Map<String, dynamic>>(
      future: companyFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final company = snapshot.data!;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(company['logo'] ?? ''),
            ),
            title: Text(company['name'] ?? ''),
            subtitle: Text(company['description'] ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsEntreprise(
                    entrepriseId: widget.product.sellerId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSimilarProducts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('categoryId', isEqualTo: widget.product.categoryId)
          .where('sellerId', isEqualTo: widget.product.sellerId)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final products = snapshot.data!.docs
            .map((doc) => Product.fromFirestore(doc))
            .where((p) => p.id != widget.product.id)
            .toList();

        if (products.isEmpty) return const SizedBox();

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
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _buildSimilarProductCard(product);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimilarProductCard(Product product) {
    final mainVariant =
        product.variants.isNotEmpty ? product.variants[0] : null;
    if (mainVariant == null) return const SizedBox();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModernProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 16),
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mainVariant.images.isNotEmpty)
                Image.network(
                  mainVariant.images[0],
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${mainVariant.price.toStringAsFixed(2)}€',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    if (selectedVariant == null) return const SizedBox();

    final hasDiscount = selectedVariant!.discount?.isValid() ?? false;
    final price = hasDiscount
        ? selectedVariant!.discount!
            .calculateDiscountedPrice(selectedVariant!.price)
        : selectedVariant!.price;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
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
                    icon: const Icon(Icons.add),
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
              child: ElevatedButton(
                onPressed: selectedVariant!.stock > 0
                    ? () => _addToCart(quantity)
                    : null,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  selectedVariant!.stock > 0
                      ? 'Ajouter au panier • ${(price * quantity).toStringAsFixed(2)}€'
                      : 'Rupture de stock',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
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
