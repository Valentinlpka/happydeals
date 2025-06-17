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
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:provider/provider.dart';

class MatchMarketSwipePage extends StatefulWidget {
  final Category category;
  final double latitude;
  final double longitude;
  final double searchRadius;
  final String cityName;

  const MatchMarketSwipePage({
    super.key,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.searchRadius,
    required this.cityName,
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
  bool _allCardsSwipedAway = false;
  final Set<String> _likedProductsIds = {};

  @override
  void initState() {
    super.initState();
    likesCount = 0;
    _loadViewedAndLikedProducts();
  }

  Future<void> _loadViewedAndLikedProducts() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final likesSnapshot = await FirebaseFirestore.instance
          .collection('liked_match_market')
          .where('userId', isEqualTo: userId)
          .get();

      final viewedSnapshot = await FirebaseFirestore.instance
          .collection('viewed_match_market')
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
      // 1. Trouver les entreprises dans le rayon
      final companiesSnapshot =
          await FirebaseFirestore.instance.collection('companys').get();

      // Filtrer les entreprises dans le rayon
      final companiesInRange = companiesSnapshot.docs.where((doc) {
        try {
          final data = doc.data();
          if (!data.containsKey('adress')) {
            return false;
          }

          final adress = data['adress'] as Map<String, dynamic>;
          if (!adress.containsKey('latitude') ||
              !adress.containsKey('longitude')) {
            return false;
          }

          final lat = adress['latitude'] as double;
          final lng = adress['longitude'] as double;

          final distance = Geolocator.distanceBetween(
                widget.latitude,
                widget.longitude,
                lat,
                lng,
              ) /
              1000; // Convertir en km

          final isInRange = distance <= widget.searchRadius;
          if (isInRange) {}
          return isInRange;
        } catch (e) {
          return false;
        }
      }).toList();

      if (companiesInRange.isEmpty) {
        setState(() {
          error = 'Aucune entreprise trouvée dans ce rayon';
          isLoading = false;
        });
        return;
      }

      // Stocker les informations des entreprises
      for (var doc in companiesInRange) {
        try {
          final company = CompanyLocation.fromFirestore(doc);
          companyLocations[company.id] = company;
        } catch (e) {
          setState(() {
            error = 'Erreur lors du chargement des entreprises: $e';
            isLoading = false;
          });
        }
      }

      // 2. Charger les produits des entreprises trouvées
      final companyIds = companiesInRange.map((doc) => doc.id).toList();

      final productsQuery = FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', whereIn: companyIds)
          .where('categoryPath', arrayContains: widget.category.id)
          .where('isActive', isEqualTo: true);

      final productsSnapshot = await productsQuery.get();

      // Filtrer les produits déjà vus
      final availableProducts = productsSnapshot.docs
          .where((doc) => !viewedProducts.contains(doc.id))
          .map((doc) {
            try {
              return Product.fromFirestore(doc);
            } catch (e) {
              return null;
            }
          })
          .where((product) => product != null)
          .cast<Product>()
          .toList();

      setState(() {
        products.addAll(availableProducts);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Erreur lors du chargement des produits: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _saveLike(Product product) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('liked_match_market').add({
        'userId': userId,
        'productId': product.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Ajouter l'ID à l'ensemble des produits likés
      _likedProductsIds.add(product.id);

      setState(() {
        likesCount = _likedProductsIds
            .length; // Mettre à jour le compteur avec le nombre exact
      });
    } catch (e) {
      setState(() {
        error = 'Erreur lors du like: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _markProductAsViewed(String productId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance.collection('viewed_match_market').add({
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

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  Widget _buildCard(Product product) {
    final companyLocation = companyLocations[product.companyId];
    String? distance;

    if (companyLocation != null) {
      final distanceKm = _calculateDistance(
        widget.latitude,
        widget.longitude,
        companyLocation.location.latitude,
        companyLocation.location.longitude,
      );
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
                Row(
                  children: [
                    Text(
                      '${availableVariant.price.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (product.variants.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withAlpha(26),
                          ),
                        ),
                        child: Text(
                          'Plusieurs variantes disponibles',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Informations sur l'entreprise et localisation
                if (companyLocation != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('companys')
                              .doc(companyLocation.id)
                              .get(),
                          builder: (context, snapshot) {
                            // Logo et nom par défaut si les données ne sont pas encore chargées
                            String? logo;
                            String? category;

                            if (snapshot.hasData && snapshot.data != null) {
                              final data = snapshot.data!.data()
                                  as Map<String, dynamic>?;
                              if (data != null) {
                                logo = data['logo'] as String?;
                                category = data['category'] as String?;
                              }
                            }

                            return Column(
                              spacing: 10,
                              children: [
                                Row(
                                  children: [
                                    // Logo de l'entreprise
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withAlpha(36),
                                        ),
                                        image: logo != null && logo.isNotEmpty
                                            ? DecorationImage(
                                                image: NetworkImage(logo),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: logo == null || logo.isEmpty
                                          ? Icon(
                                              Icons.store,
                                              size: 18,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            companyLocation.name.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          // Catégorie de l'entreprise
                                          if (category != null &&
                                              category.isNotEmpty)
                                            Text(
                                              category.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                              ],
                            );
                          },
                        ),
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withAlpha(26),
                                border: Border.all(
                                    color: Colors.blue.withAlpha(76)),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('companys')
                                    .doc(companyLocation.id)
                                    .get(),
                                builder: (context, snapshot) {
                                  String cityName = companyLocation.city;

                                  // Si la ville est vide, essayons de la récupérer directement depuis Firestore
                                  if (cityName.isEmpty &&
                                      snapshot.hasData &&
                                      snapshot.data != null) {
                                    final data = snapshot.data!.data()
                                        as Map<String, dynamic>?;
                                    if (data != null &&
                                        data.containsKey('adress')) {
                                      final address = data['adress']
                                          as Map<String, dynamic>;
                                      cityName = address['city'] ?? '';
                                    }
                                  }

                                  return Text(
                                    cityName.isEmpty
                                        ? 'LOCALISATION INCONNUE'
                                        : cityName.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ),
                            if (distance != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(26),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  distance,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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

  Widget _buildEndScreen() {
    // Couleurs personnalisées
    const Color primaryColor = Color(0xFF6C63FF);
    const Color secondaryColor = Color(0xFFFF6584);
    const Color backgroundColor = Color(0xFFF8F9FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.category.name,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withAlpha(52),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'Vous avez tout vu !',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Vous avez liké $likesCount produits',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(26),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LikedProductsPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.favorite, color: Colors.white),
                      label: const Text(
                        'Voir mes coups de cœur',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                    icon: const Icon(Icons.category, color: primaryColor),
                    label: const Text(
                      'Choisir une autre catégorie',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      side: const BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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

    if (_allCardsSwipedAway || products.isEmpty) {
      return _buildEndScreen();
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.category.name,
        align: Alignment.center,
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
              backCardOffset: const Offset(0, -10),
              allowedSwipeDirection:
                  const AllowedSwipeDirection.only(left: true, right: true),
              maxAngle: 25,
              threshold: 50,
              isLoop: false,
              duration: const Duration(milliseconds: 400),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              onSwipe: (int previousIndex, int? currentIndex,
                  CardSwiperDirection direction) {
                // Traiter le swipe sans modifier la liste
                final product = products[previousIndex];

                // Marquer comme vu
                _markProductAsViewed(product.id);

                // Gérer les likes avec plus de logs
                if (direction == CardSwiperDirection.right) {
                  _saveLike(product);
                } else {}

                // Si c'était le dernier produit, afficher l'écran de fin après un court délai
                if (currentIndex == null || currentIndex >= products.length) {}

                return true; // Toujours autoriser le swipe
              },
              onEnd: () {
                setState(() {
                  _allCardsSwipedAway = true;
                  likesCount =
                      _likedProductsIds.length; // Utiliser le nombre exact
                });
              },
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
