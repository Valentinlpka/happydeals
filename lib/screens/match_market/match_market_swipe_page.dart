import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/category_product.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/models/company_location.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/match_market/liked_products_page.dart';
import 'package:happy/screens/match_market/match_market_intro_page.dart';
import 'package:provider/provider.dart';

class MatchMarketSwipePage extends StatefulWidget {
  final Category category;
  final Position? userPosition;
  final double searchRadius;
  final String? citySearch;

  const MatchMarketSwipePage({
    super.key,
    required this.category,
    this.userPosition,
    required this.searchRadius,
    this.citySearch,
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
  Map<String, CompanyLocation> companyLocations = {};
  bool _isProcessingSwipe = false;
  Product? _currentProduct;

  @override
  void initState() {
    super.initState();
    _loadViewedAndLikedProducts();
  }

  Future<void> _loadViewedAndLikedProducts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

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

      await _loadProducts();
    } catch (e) {
      setState(() {
        error = 'Erreur lors du chargement des produits vus';
        isLoading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    try {
      print('🔍 Début du chargement des produits');
      Query productsQuery = FirebaseFirestore.instance
          .collection('products')
          .where('categoryPath', arrayContains: widget.category.id)
          .where('isActive', isEqualTo: true);

      if (widget.citySearch != null) {
        print('🏙️ Recherche par ville: ${widget.citySearch}');
        productsQuery =
            productsQuery.where('city', isEqualTo: widget.citySearch);
      }

      print('📥 Récupération des produits depuis Firestore...');
      final snapshot = await productsQuery.get();
      print('📦 Nombre de produits trouvés: ${snapshot.docs.length}');

      // Filtrer d'abord les produits déjà vus
      final availableDocs =
          snapshot.docs.where((doc) => !viewedProducts.contains(doc.id));
      print('📦 Nombre de produits non vus: ${availableDocs.length}');

      final allProducts = availableDocs
          .map((doc) {
            try {
              print('🔄 Conversion du produit ${doc.id}:');
              print('  - Données brutes: ${doc.data()}');
              final product = Product.fromFirestore(doc);
              print('  - Nom: ${product.name}');
              print('  - Images: ${product.images.length} images');
              print('  - CompanyId: ${product.companyId}');
              return product;
            } catch (e) {
              print('❌ Erreur lors de la conversion du produit ${doc.id}: $e');
              return null;
            }
          })
          .where((p) => p != null)
          .cast<Product>()
          .toList();

      print('📝 Nombre de produits convertis: ${allProducts.length}');

      // Charger les informations des entreprises
      print('🏢 Chargement des informations des entreprises...');
      final companyIds = allProducts.map((p) => p.companyId).toSet();
      print('🏢 Nombre d\'entreprises à charger: ${companyIds.length}');

      for (final companyId in companyIds) {
        try {
          print('🏢 Chargement de l\'entreprise: $companyId');
          final companyDoc = await FirebaseFirestore.instance
              .collection('companys')
              .doc(companyId)
              .get();

          if (companyDoc.exists) {
            print('✅ Entreprise trouvée: $companyId');
            companyLocations[companyId] =
                CompanyLocation.fromFirestore(companyDoc);
          } else {
            print('⚠️ Entreprise non trouvée: $companyId');
          }
        } catch (e) {
          print('❌ Erreur lors du chargement de l\'entreprise $companyId: $e');
        }
      }

      // Filtrer les produits par distance
      print('📏 Filtrage des produits par distance...');
      print(
          '📍 Position utilisateur: ${widget.userPosition?.latitude}, ${widget.userPosition?.longitude}');
      print('🎯 Rayon de recherche: ${widget.searchRadius} km');

      final filteredProducts = allProducts.where((product) {
        final companyLocation = companyLocations[product.companyId];
        if (companyLocation != null && widget.userPosition != null) {
          final distance =
              companyLocation.distanceFromUser(widget.userPosition!);
          print('📍 Distance pour ${product.name}: $distance km');
          return distance <= widget.searchRadius;
        }
        print('ℹ️ Pas de filtrage par distance pour ${product.name}');
        return widget.citySearch != null;
      }).toList();

      print('✅ Nombre de produits filtrés: ${filteredProducts.length}');

      setState(() {
        products.addAll(filteredProducts);
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Erreur lors du chargement des produits:');
      print('Message d\'erreur: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        error = 'Erreur lors du chargement des produits: $e';
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

  void _showShareDialog(Product product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                    "Partager avec...",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<String>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .snapshots()
                        .map((doc) => List<String>.from(
                            doc.data()?['followedUsers'] ?? [])),
                    builder: (context, followedSnapshot) {
                      if (!followedSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final followedUsers = followedSnapshot.data!;

                      return FutureBuilder<List<DocumentSnapshot>>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: followedUsers)
                            .get()
                            .then((query) => query.docs),
                        builder: (context, usersSnapshot) {
                          if (!usersSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final usersList = usersSnapshot.data!;

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: usersList.length,
                            itemBuilder: (context, index) {
                              final userData = usersList[index].data()
                                  as Map<String, dynamic>;
                              final userId = usersList[index].id;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: userData['image_profile'] !=
                                          null
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
                                    final conversationService =
                                        Provider.of<ConversationService>(
                                            context,
                                            listen: false);
                                    await conversationService
                                        .shareProductInConversation(
                                      senderId: FirebaseAuth
                                          .instance.currentUser!.uid,
                                      receiverId: userId,
                                      productId: product.id,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Produit partagé avec succès'),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Erreur lors du partage: $e'),
                                      ),
                                    );
                                  }
                                },
                              );
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

  Widget _buildCard(Product product) {
    final companyLocation = companyLocations[product.companyId];
    String? distance;
    if (widget.userPosition != null && companyLocation != null) {
      final distanceKm = companyLocation.distanceFromUser(widget.userPosition!);
      distance = '${distanceKm.toStringAsFixed(1)} km';
    }

    // Récupérer la première variante disponible en stock
    final availableVariant = product.variants.firstWhere(
      (v) => v.stock > 0,
      orElse: () => product.variants.first,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: availableVariant.images.isNotEmpty
                  ? Image.network(
                      availableVariant.images.first,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                    ),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${availableVariant.price.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (availableVariant.attributes.isNotEmpty)
                  Text(
                    availableVariant.attributes.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' • '),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 8),
                if (companyLocation != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.store, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          companyLocation.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          companyLocation.city +
                              (distance != null ? ' • $distance' : ''),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.red,
                  onPressed: () => controller.swipe(CardSwiperDirection.left),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  color: Colors.blue,
                  onPressed: () => _showShareDialog(product),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite),
                  color: Colors.green,
                  onPressed: () => controller.swipe(CardSwiperDirection.right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _handleSwipe(
      int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (_isProcessingSwipe) return false;
    _isProcessingSwipe = true;

    try {
      if (previousIndex >= 0 && previousIndex < products.length) {
        final product = products[previousIndex];
        print('👆 Traitement du swipe pour le produit: ${product.name}');
        print('📊 Index actuel: $previousIndex, Prochain index: $currentIndex');
        print('📊 Nombre de produits avant suppression: ${products.length}');

        Future.delayed(const Duration(milliseconds: 100), () async {
          if (!mounted) return;

          await _markProductAsViewed(product.id);
          if (direction == CardSwiperDirection.right) {
            await _saveLike(product);
          }

          if (!mounted) return;

          setState(() {
            if (products.contains(product)) {
              products.remove(product);
              print('✅ Produit retiré de la liste: ${product.name}');
              print('📊 Nombre de produits restants: ${products.length}');
            }
          });

          _isProcessingSwipe = false;
        });

        return true;
      }
    } catch (e) {
      print('❌ Erreur lors du traitement du swipe: $e');
    }

    _isProcessingSwipe = false;
    return false;
  }

  Widget _buildEndScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                        vertical: 16,
                        horizontal: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MatchMarketIntroPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Choisir une autre catégorie'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(error!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    error = null;
                    isLoading = true;
                  });
                  _loadViewedAndLikedProducts();
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (products.isEmpty) {
      return _buildEndScreen();
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
                  builder: (context) => const LikedProductsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CardSwiper(
              controller: controller,
              cardsCount: products.length,
              numberOfCardsDisplayed: 1,
              backCardOffset: const Offset(0, 0),
              allowedSwipeDirection:
                  const AllowedSwipeDirection.only(left: true, right: true),
              maxAngle: 25,
              threshold: 50,
              isLoop: false,
              duration: const Duration(milliseconds: 600),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              onSwipe: _handleSwipe,
              cardBuilder: (context, index, horizontalOffsetPercentage,
                  verticalOffsetPercentage) {
                if (index >= products.length) {
                  return const SizedBox.shrink();
                }
                return _buildCard(products[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
