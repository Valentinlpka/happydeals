import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/services/like_service.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/product_card.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

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
  late Future<Company> companyFuture;

  @override
  void initState() {
    super.initState();
    companyFuture = _loadCompanyData();
    if (widget.product.variants.isNotEmpty) {
      selectedVariant = widget.product.variants[0];
      selectedAttributes = Map.from(selectedVariant!.attributes);
    }
  }

  Future<Company> _loadCompanyData() async {
    final doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(widget.product.sellerId)
        .get();
    return Company.fromDocument(doc);
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: CustomScrollView(
              slivers: [
                _buildSliverAppBar(isFavorite),
                SliverToBoxAdapter(
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (selectedVariant != null)
                              _buildPriceSection(hasDiscount),
                            _buildVariantSelector(),
                            const SizedBox(height: 10),
                            _buildProductDetails(),
                            const SizedBox(height: 16),
                            _buildSellerInfo(),
                            _buildSimilarProducts(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isFavorite) {
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
          stream: LikeService.isLiked(widget.product.id),
          builder: (context, snapshot) {
            final isLiked = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.black,
              ),
              onPressed: () =>
                  LikeService.toggleLike(widget.product.id, context),
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
                attribute[0].toUpperCase() +
                    attribute.substring(1).toLowerCase(),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: BorderSide(
                      width: isSelected ? 0 : 1,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  color: WidgetStatePropertyAll(
                      isSelected ? Colors.blue[700] : Colors.white),
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

  Widget _buildProductDetails() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.product.description),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
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
          FutureBuilder<Company>(
            future: companyFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return CompanyInfoCard(
                company: snapshot.data!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsEntreprise(
                      entrepriseId: widget.product.sellerId,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
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

  Widget _buildBottomSheet() {
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
            color: Colors.grey.withOpacity(0.3),
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
    // Construire l'URL avec les métadonnées Open Graph
    final String productUrl = Uri.encodeFull(
        "https://happy-deals-3f03d.web.app/produits/${widget.product.id}"); // Remplacez par votre URL réelle
    final String productImage = selectedVariant?.images.first ?? '';
    final String description = widget.product.description.length > 100
        ? '${widget.product.description.substring(0, 97)}...'
        : widget.product.description;

    // Texte de partage avec métadonnées pour les réseaux sociaux
    final String shareText = """
${widget.product.name}

$description

Découvrez ce produit sur notre boutique!
$productUrl
""";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Partager avec',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    icon:
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Facebook_Logo_%282019%29.png/1200px-Facebook_Logo_%282019%29.png',
                    label: 'Facebook',
                    onTap: () {
                      // URL avec paramètres Open Graph pour Facebook
                      final fbUrl = Uri.encodeFull(
                          "https://www.facebook.com/sharer/sharer.php?u=$productUrl");
                      html.window.open(fbUrl, 'facebook-share');
                      Navigator.pop(context);
                    },
                  ),
                  _buildShareOption(
                    icon:
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Logo_of_Twitter.svg/512px-Logo_of_Twitter.svg.png',
                    label: 'Twitter',
                    onTap: () {
                      final twitterUrl = Uri.encodeFull(
                          "https://twitter.com/intent/tweet?text=${Uri.encodeFull(shareText)}");
                      html.window.open(twitterUrl, 'twitter-share');
                      Navigator.pop(context);
                    },
                  ),
                  _buildShareOption(
                    icon:
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6b/WhatsApp.svg/767px-WhatsApp.svg.png',
                    label: 'WhatsApp',
                    onTap: () async {
                      final whatsappUrl = "whatsapp://send?text=$shareText";
                      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
                        await launchUrl(Uri.parse(whatsappUrl));
                      }
                      Navigator.pop(context);
                    },
                  ),
                  _buildShareOption(
                    icon:
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/83/Telegram_2019_Logo.svg/512px-Telegram_2019_Logo.svg.png',
                    label: 'Telegram',
                    onTap: () async {
                      final telegramUrl =
                          "https://t.me/share/url?url=$productUrl&text=${widget.product.name}";
                      if (await canLaunchUrl(Uri.parse(telegramUrl))) {
                        await launchUrl(Uri.parse(telegramUrl));
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(
                    icon:
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e7/Instagram_logo_2016.svg/132px-Instagram_logo_2016.svg.png',
                    label: 'Instagram',
                    onTap: () async {
                      // Instagram ne permet pas le partage direct via URL, on utilise le partage général
                      await Share.share(shareText,
                          subject: widget.product.name);
                      Navigator.pop(context);
                    },
                  ),
                  _buildShareOption(
                    icon: 'https://www.svgrepo.com/show/13667/link.svg',
                    label: 'Copier le lien',
                    onTap: () {
                      Navigator.pop(context);
                      // Utiliser l'API Clipboard du web
                      html.window.navigator.clipboard
                          ?.writeText(productUrl)
                          .then((_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lien copié dans le presse-papiers'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      });
                    },
                  ),
                  _buildShareOption(
                    icon:
                        'https://www.svgrepo.com/show/533241/message-dots.svg',
                    label: 'SMS',
                    onTap: () async {
                      final smsUrl = "sms:?body=$shareText";
                      if (await canLaunchUrl(Uri.parse(smsUrl))) {
                        await launchUrl(Uri.parse(smsUrl));
                      }
                      Navigator.pop(context);
                    },
                  ),
                  _buildShareOption(
                    icon: 'https://www.svgrepo.com/show/533211/mail.svg',
                    label: 'Email',
                    onTap: () async {
                      final emailUrl =
                          "mailto:?subject=${widget.product.name}&body=$shareText";
                      if (await canLaunchUrl(Uri.parse(emailUrl))) {
                        await launchUrl(Uri.parse(emailUrl));
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.network(
              icon,
              width: 36,
              height: 36,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
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
