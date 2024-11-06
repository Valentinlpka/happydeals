import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/widgets/deal_product.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class DetailsHappyDeals extends StatefulWidget {
  final HappyDeal happydeal;
  final String cover;

  const DetailsHappyDeals({
    super.key,
    required this.happydeal,
    required this.cover,
  });

  @override
  // ignore: library_private_types_in_public_api
  _DetailsHappyDealsState createState() => _DetailsHappyDealsState();
}

class _DetailsHappyDealsState extends State<DetailsHappyDeals> {
  late Future<Product?> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture = _fetchProduct();
  }

  Future<Product?> _fetchProduct() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.happydeal.productId)
          .get();

      if (doc.exists) {
        return Product.fromDocument(doc);
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération du produit: $e');
      return null;
    }
  }

  String getRemainingTime() {
    final now = DateTime.now();
    final difference = widget.happydeal.endDate.difference(now);
    final days = difference.inDays;

    if (difference.isNegative) {
      return 'Ce deal a expiré';
    } else if (days == 0) {
      // Si c'est le dernier jour, calculons les heures restantes
      final hours = difference.inHours;
      if (hours == 0) {
        final minutes = difference.inMinutes;
        return 'Ce deal expire dans $minutes minute${minutes > 1 ? 's' : ''}';
      }
      return 'Ce deal expire dans $hours heure${hours > 1 ? 's' : ''}';
    } else if (days == 1) {
      return 'Ce deal expire demain';
    } else {
      return 'Ce deal expire dans $days jours';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy', 'fr_FR')
        .format(dateTime); // Format comme "2024-06-13"
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.happydeal.id);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            elevation: 1,
            centerTitle: true,
            titleSpacing: 50,
            title: Container(
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color.fromARGB(115, 0, 0, 0),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    Text(
                      maxLines: 1,
                      'Happy Deals',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.blue[700],
            leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
              ),
            ),
            actions: [
              Consumer<UserModel>(
                builder: (context, users, _) {
                  return IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                    ),
                    onPressed: () async {
                      await users.handleLike(widget.happydeal);
                      setState(() {}); // Force a rebuild to update the UI
                    },
                  );
                },
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.share,
                  color: Colors.white,
                ),
              ),
            ],
            expandedHeight: 200,
            flexibleSpace: FutureBuilder<Product?>(
              future: _productFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return FlexibleSpaceBar(
                    background: Image.network(
                      widget.cover,
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.30),
                      colorBlendMode: BlendMode.darken,
                    ),
                  );
                }

                final product = snapshot.data!;

                return FlexibleSpaceBar(
                  background: Image.network(
                    product.imageUrl[
                        0], // Utilisation de la première image du produit
                    fit: BoxFit.fitWidth,
                    color: Colors.black.withOpacity(0.30),
                    colorBlendMode: BlendMode.darken,
                  ),
                );
              },
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            floating: false,
            delegate: _SliverHeaderDelegate(
              minHeight: 30,
              maxHeight: 30,
              child: Container(
                color: Colors.blue[700],
                child: Center(
                  child: Text(
                    getRemainingTime(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsEntreprise(
                                entrepriseId: widget.happydeal.companyId),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.blue[700],
                            child: const CircleAvatar(
                              radius: 25,
                              backgroundImage: NetworkImage(
                                  'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                            width: 10,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Be Happy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    color: Colors.blue[700],
                                    child: const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                    width: 10,
                                  ),
                                  const Text(
                                    '4,4',
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                    width: 5,
                                  ),
                                  // Your rating widget here
                                  const Text(
                                    '(45 avis)',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.happydeal.title),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(widget.happydeal.description),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Détail du deal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      Column(
                        children: [
                          FutureBuilder<Product?>(
                            future: _productFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const CircularProgressIndicator();
                              }

                              if (!snapshot.hasData || snapshot.data == null) {
                                return const Text('Produit non disponible');
                              }

                              final product = snapshot.data!;

                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProductDetailPage(product: product),
                                    ),
                                  );
                                },
                                child: DealProduct(
                                  name: widget.happydeal.productName,
                                  oldPrice: widget.happydeal.oldPrice,
                                  newPrice: widget.happydeal.newPrice,
                                  discount: widget.happydeal.discountPercentage,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Validité du deal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      Text(
                        '${formatDateTime(widget.happydeal.startDate)} - ${formatDateTime(widget.happydeal.endDate)} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Comment en profiter ?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Blabla blabla blabla',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Comment nous contacter ?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        "Partie contact de l'annuaire",
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Localisation ?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        '59 Rue Maurice Boutton, 59135, Wallers, France',
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      SizedBox(
                        height: 200,
                        child: FlutterMap(
                          mapController: MapController(),
                          options: const MapOptions(
                            initialCenter:
                                LatLng(50.37714385986328, 3.4123148918151855),
                            initialZoom: 14,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              // Plenty of other options available!
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: const LatLng(
                                      50.37714385986328, 3.4123148918151855),
                                  width: 100,
                                  height: 100,
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.red[800],
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                        width: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder<Product?>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: const Center(
                child: Text('Produit non disponible'),
              ),
            );
          }

          final product = snapshot.data!;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${product.discountedPrice?.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${product.price.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 16,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '-${product.discountPercentage?.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[700]!, Colors.blue[800]!],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              spreadRadius: 0,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              try {
                                context.read<CartService>().addToCart(product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.white),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Produit ajouté',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              Text(
                                                'Votre produit a été ajouté au panier',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.blue[800],
                                    duration: const Duration(seconds: 4),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
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
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_cart_outlined,
                                    color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Ajouter au panier',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate.maxExtent != maxExtent ||
        oldDelegate.minExtent != minExtent ||
        (oldDelegate as _SliverHeaderDelegate).child != child;
  }
}
