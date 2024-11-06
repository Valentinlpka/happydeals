import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:provider/provider.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int current = 0;
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    bool hasDiscount = widget.product.hasActiveHappyDeal &&
        widget.product.discountedPrice != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black),
            onPressed: () {
              // Implémenter le partage
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 300,
                          aspectRatio: 1,
                          viewportFraction: 1,
                          enlargeCenterPage: false,
                          enableInfiniteScroll:
                              widget.product.imageUrl.length > 1,
                          onPageChanged: (index, reason) {
                            setState(() {
                              current = index;
                            });
                          },
                        ),
                        items: widget.product.imageUrl.map((url) {
                          return Image.network(
                            url,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          );
                        }).toList(),
                      ),
                      if (hasDiscount)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '-${widget.product.discountPercentage?.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: widget.product.imageUrl
                              .asMap()
                              .entries
                              .map((entry) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: current == entry.key
                                    ? Colors.black
                                    : Colors.black.withOpacity(0.5),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
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
                        if (hasDiscount) ...[
                          Row(
                            children: [
                              Text(
                                '${widget.product.price.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 16,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.product.discountedPrice!.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Text(
                            '${widget.product.price.toStringAsFixed(2)}€',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 16),
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.product.description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (widget.product.stock > 0)
                          Text(
                            '${widget.product.stock} en stock',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          const Text(
                            'Rupture de stock',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -1),
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
                            if (quantity > 1) {
                              setState(() => quantity--);
                            }
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
                            if (quantity < widget.product.stock) {
                              setState(() => quantity++);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0B7FE9).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: widget.product.stock > 0
                              ? () {
                                  for (var i = 0; i < quantity; i++) {
                                    context
                                        .read<CartService>()
                                        .addToCart(widget.product);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: Colors.white),
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
                                              builder: (context) =>
                                                  const CartScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: Center(
                            child: Text(
                              widget.product.stock > 0
                                  ? 'Ajouter au panier'
                                  : 'Indisponible',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
