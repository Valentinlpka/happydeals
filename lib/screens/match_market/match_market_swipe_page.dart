import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:happy/classes/category_product.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/match_market/liked_products_page.dart';
import 'package:happy/screens/match_market/match_market_intro_page.dart';

class MatchMarketSwipePage extends StatefulWidget {
  final Category category;

  const MatchMarketSwipePage({
    super.key,
    required this.category,
  });

  @override
  State<MatchMarketSwipePage> createState() => _MatchMarketSwipePageState();
}

class _MatchMarketSwipePageState extends State<MatchMarketSwipePage> {
  final CardSwiperController controller = CardSwiperController();
  final List<Product> products = [];
  bool isLoading = true;
  String? error;
  int likesCount = 0;
  Set<String> viewedProducts = {};

  @override
  void initState() {
    super.initState();
    _loadViewedAndLikedProducts();
  }

  Future<void> _loadViewedAndLikedProducts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      print('Loading viewed and liked products');

      try {
        final likesSnapshot = await FirebaseFirestore.instance
            .collection('likes')
            .where('userId', isEqualTo: userId)
            .get();

        final viewedSnapshot = await FirebaseFirestore.instance
            .collection('viewed_products')
            .where('userId', isEqualTo: userId)
            .get();

        setState(() {
          viewedProducts = {
            ...likesSnapshot.docs.map((doc) => doc['productId'] as String),
            ...viewedSnapshot.docs.map((doc) => doc['productId'] as String),
          };
        });
      } catch (e) {
        print('Firebase error details: $e');
        if (e is FirebaseException && e.code == 'failed-precondition') {
          print('Index needed: ${e.message}');
          print('Please create the following index:');
          final indexUrl =
              e.message?.split('https://console.firebase.google.com/')[1];
          if (indexUrl != null) {
            print('https://console.firebase.google.com$indexUrl');
          }
        }
        rethrow;
      }

      print('Found ${viewedProducts.length} viewed/liked products');
      await _loadProducts();
    } catch (e) {
      print('Error loading viewed/liked products: $e');
    }
  }

  Future<void> _loadProducts() async {
    try {
      final categoryDoc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.category.id)
          .get();

      final categoryData = categoryDoc.data() as Map<String, dynamic>;
      final categoryPath = categoryData['path'] as List<dynamic>? ?? [];

      print('Loading products for category path: $categoryPath');

      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('categoryPath',
              arrayContainsAny: [...categoryPath, widget.category.id]).get();

      final filteredProducts = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .where((product) => !viewedProducts.contains(product.id))
          .toList();

      print('Found ${filteredProducts.length} new products to show');

      setState(() {
        products.addAll(filteredProducts);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        error = 'Erreur lors du chargement des produits';
        isLoading = false;
      });
    }
  }

  Future<void> _saveLike(Product product) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance.collection('likes').add({
      'userId': userId,
      'productId': product.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      likesCount++;
    });
  }

  Future<void> _markProductAsViewed(String productId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance.collection('viewed_products').add({
      'userId': userId,
      'productId': productId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      viewedProducts.add(productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(child: Text(error!)),
      );
    }

    if (products.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Match Market'),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green[400],
              ),
              const SizedBox(height: 24),
              const Text(
                'Vous avez tout vu !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vous avez liké $likesCount produits',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LikedProductsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.favorite),
                label: const Text('Voir mes coups de cœur'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MatchMarketIntroPage(),
                    ),
                  );
                },
                child: const Text('Choisir une autre catégorie'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LikedProductsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CardSwiper(
                controller: controller,
                cardsCount: products.length,
                onSwipe: _handleSwipe,
                numberOfCardsDisplayed:
                    products.length < 3 ? products.length : 3,
                backCardOffset: const Offset(40, 40),
                padding: const EdgeInsets.all(24.0),
                cardBuilder:
                    (context, index, horizontalThreshold, verticalThreshold) =>
                        _buildCard(products[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: () => controller.swipe(CardSwiperDirection.left),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.close),
                  ),
                  FloatingActionButton(
                    onPressed: () =>
                        controller.swipe(CardSwiperDirection.right),
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.favorite),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Product product) {
    final mainVariant =
        product.variants.isNotEmpty ? product.variants[0] : null;
    if (mainVariant == null) return const SizedBox();

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: mainVariant.images.isNotEmpty
                  ? Image.network(
                      mainVariant.images[0],
                      fit: BoxFit.cover,
                    )
                  : const Center(child: Icon(Icons.image, size: 100)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${mainVariant.price.toStringAsFixed(2)}€',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    final product = products[previousIndex];

    if (direction == CardSwiperDirection.right) {
      await _saveLike(product);
    }

    await _markProductAsViewed(product.id);

    setState(() {
      products.removeAt(previousIndex);
    });

    return true;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
