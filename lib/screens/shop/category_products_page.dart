import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:provider/provider.dart';

class CategoryProductsPage extends StatefulWidget {
  final String categoryName;
  final String categoryId;

  const CategoryProductsPage({
    super.key,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _selectedCompanies = [];
  List<Map<String, dynamic>> _companies = [];
  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final userProvider = Provider.of<UserModel>(context, listen: false);
    if (userProvider.latitude != 0.0 && userProvider.longitude != 0.0) {
      setState(() {
        _userLat = userProvider.latitude;
        _userLng = userProvider.longitude;
      });
    }
  }

  String _formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    }
    return '${distance.toStringAsFixed(1)}km';
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  double? _calculateDistance(Map<String, dynamic> address) {
    if (_userLat == null ||
        _userLng == null ||
        !address.containsKey('latitude') ||
        !address.containsKey('longitude')) {
      return null;
    }

    final companyLat = address['latitude'] as double;
    final companyLng = address['longitude'] as double;

    const double earthRadius = 6371;
    final latDiff = _degreesToRadians(companyLat - _userLat!);
    final lngDiff = _degreesToRadians(companyLng - _userLng!);

    final a = sin(latDiff / 2) * sin(latDiff / 2) +
        cos(_degreesToRadians(_userLat!)) *
            cos(_degreesToRadians(companyLat)) *
            sin(lngDiff / 2) *
            sin(lngDiff / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _loadCompanies() async {
    final companiesSnapshot = await _firestore
        .collection('companys')
        .where('hasProducts', isEqualTo: true)
        .get();

    setState(() {
      _companies = companiesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? '',
                'logo': doc.data()['logo'] ?? '',
              })
          .toList();
    });
  }

  void _showCompanyFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtrer par entreprise',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCompanies.clear();
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _companies.length,
                      itemBuilder: (context, index) {
                        final company = _companies[index];
                        return CheckboxListTile(
                          value: _selectedCompanies.contains(company['id']),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedCompanies.add(company['id']);
                              } else {
                                _selectedCompanies.remove(company['id']);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              if (company['logo'].isNotEmpty)
                                CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(company['logo']),
                                  radius: 20,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  company['name'],
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B88DA),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: const Text(
                      'Appliquer les filtres',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: widget.categoryName,
        align: Alignment.center,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showCompanyFilters,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .where('type', isEqualTo: 'product')
            .where('categoryPath', arrayContains: widget.categoryId)
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('Erreur Firestore: ${snapshot.error}');
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final products = snapshot.data?.docs ?? [];
          debugPrint("Nombre total de documents: ${products.length}");
          
          final filteredProducts = _selectedCompanies.isEmpty
              ? products
              : products
                  .where((product) {
                    final data = product.data() as Map<String, dynamic>;
                    debugPrint("Données du produit: $data");
                    final companyId = data['companyId']?.toString() ?? '';
                    return companyId.isNotEmpty && _selectedCompanies.contains(companyId);
                  })
                  .toList();

          debugPrint("Nombre de produits filtrés: ${filteredProducts.length}");

          if (filteredProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun produit dans cette catégorie',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65, // Ajusté pour donner plus d'espace vertical
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final productDoc = filteredProducts[index];
              final productData = productDoc.data() as Map<String, dynamic>;
              debugPrint("Construction du produit ${index + 1}/${filteredProducts.length}");
              debugPrint("ID du produit: ${productDoc.id}");

              Product? product;
              try {
                product = Product.fromFirestore(productDoc);
                debugPrint("Product créé avec succès: ${product.name}");
              } catch (e) {
                debugPrint('Erreur lors de la conversion du produit: $e');
                return const SizedBox.shrink();
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ModernProductDetailPage(
                          product: product!,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image du produit
                      Expanded(
                        flex: 5, // Augmenté pour donner plus d'espace à l'image
                        child: Stack(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: product.images.isNotEmpty
                                    ? Image.network(
                                        product.images[0],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder: (context, error, stackTrace) {
                                          debugPrint("Erreur de chargement d'image: $error");
                                          return Container(
                                            color: Colors.grey[100],
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.image_not_supported_outlined,
                                                    size: 32,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Image non disponible',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey[100],
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.image_not_supported_outlined,
                                                size: 32,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Pas d\'image',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            if (product.discount?.isValid() ?? false)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red[700],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '-${product.discount!.value}${product.discount!.type == 'percentage' ? '%' : '€'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Informations du produit
                      Container(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (product.discount?.isValid() ?? false) ...[
                              Text(
                                '${product.basePrice.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${product.finalPrice.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ] else
                              Text(
                                '${product.basePrice.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ));
            },
          );
        },
      ),
    );
  }
}

