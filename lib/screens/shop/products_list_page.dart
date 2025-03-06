import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/widgets/custom_app_bar.dart';

class ProductsListPage extends StatefulWidget {
  final String title;
  final Query<Map<String, dynamic>> query;
  final bool showDistance;
  final double? userLat;
  final double? userLng;

  const ProductsListPage({
    super.key,
    required this.title,
    required this.query,
    this.showDistance = false,
    this.userLat,
    this.userLng,
  });

  @override
  State<ProductsListPage> createState() => _ProductsListPageState();
}

enum SortOption {
  priceAsc,
  priceDesc,
  newest,
  distance,
}

class _ProductsListPageState extends State<ProductsListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _selectedCompanies = [];
  final List<String> _selectedCategories = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, List<Map<String, dynamic>>> _categoriesByParent = {};
  List<Map<String, dynamic>> _currentCategories = [];
  List<Map<String, dynamic>> _breadcrumbs = [];
  SortOption _currentSort = SortOption.newest;
  final List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 20;
  DocumentSnapshot? _lastDocument;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadCategories();
    _scrollController.addListener(_onScroll);
    _loadMoreProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadMoreProducts();
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query<Map<String, dynamic>> query = widget.query;

      // Appliquer les filtres de catégories
      if (_selectedCategories.isNotEmpty) {
        query =
            query.where('categoryPath', arrayContainsAny: _selectedCategories);
      }

      // Appliquer les filtres d'entreprises
      if (_selectedCompanies.isNotEmpty) {
        query = query.where('sellerId', whereIn: _selectedCompanies);
      }

      if (_currentSort != SortOption.newest) {
        switch (_currentSort) {
          case SortOption.priceAsc:
            query = query.orderBy('basePrice', descending: false);
            break;
          case SortOption.priceDesc:
            query = query.orderBy('basePrice', descending: true);
            break;
          case SortOption.distance:
            // Le tri par distance est géré côté client
            break;
          default:
            break;
        }
      }

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }
      query = query.limit(_limit);

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;
      final newProducts =
          snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();

      setState(() {
        _products.addAll(newProducts);
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des produits: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetProducts() {
    setState(() {
      _products.clear();
      _lastDocument = null;
      _hasMore = true;
      _isLoading = false;
    });
    _loadMoreProducts();
  }

  Future<void> _loadCompanies() async {
    try {
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
    } catch (e) {
      print('Erreur lors du chargement des entreprises: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoriesSnapshot = await _firestore
          .collection('categories')
          .orderBy('level')
          .orderBy('name')
          .get();

      final allCategories = categoriesSnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? '',
                'level': doc.data()['level'] ?? 1,
                'parentId': doc.data()['parentId'],
                'icon': doc.data()['icon'],
              })
          .toList();

      // Organiser les catégories par parent
      final Map<String, List<Map<String, dynamic>>> categoriesByParent = {};
      for (var category in allCategories) {
        final parentId = category['parentId'] ?? 'root';
        if (!categoriesByParent.containsKey(parentId)) {
          categoriesByParent[parentId] = [];
        }
        categoriesByParent[parentId]!.add(category);
      }

      setState(() {
        _categories = allCategories;
        _categoriesByParent = categoriesByParent;
        _currentCategories = categoriesByParent['root'] ?? [];
      });
    } catch (e) {
      print('Erreur lors du chargement des catégories: $e');
    }
  }

  void _showSortFilterBottomSheet() {
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
                  const Text(
                    'Trier par',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Prix croissant'),
                        selected: _currentSort == SortOption.priceAsc,
                        onSelected: (selected) {
                          setState(() {
                            _currentSort = SortOption.priceAsc;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Prix décroissant'),
                        selected: _currentSort == SortOption.priceDesc,
                        onSelected: (selected) {
                          setState(() {
                            _currentSort = SortOption.priceDesc;
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Plus récents'),
                        selected: _currentSort == SortOption.newest,
                        onSelected: (selected) {
                          setState(() {
                            _currentSort = SortOption.newest;
                          });
                        },
                      ),
                      if (widget.showDistance)
                        FilterChip(
                          label: const Text('Distance'),
                          selected: _currentSort == SortOption.distance,
                          onSelected: (selected) {
                            setState(() {
                              _currentSort = SortOption.distance;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Filtrer par entreprise',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedCompanies.clear();
                              _currentSort = SortOption.newest;
                            });
                            Navigator.pop(context);
                            _resetProducts();
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B88DA),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _resetProducts();
                          },
                          child: const Text(
                            'Appliquer',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoriesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtrer par catégorie',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedCategories.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategories.clear();
                                  _currentCategories =
                                      _categoriesByParent['root'] ?? [];
                                  _breadcrumbs.clear();
                                });
                              },
                              child: const Text('Tout effacer'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Fil d'Ariane
                      if (_breadcrumbs.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _breadcrumbs.clear();
                                    _currentCategories =
                                        _categoriesByParent['root'] ?? [];
                                  });
                                },
                                child: const Text(
                                  'Catégories',
                                  style: TextStyle(
                                    color: Color(0xFF4B88DA),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              ...List.generate(_breadcrumbs.length * 2 - 1,
                                  (index) {
                                if (index.isOdd) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(
                                      Icons.chevron_right,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                final breadcrumbIndex = index ~/ 2;
                                final category = _breadcrumbs[breadcrumbIndex];
                                final isLast =
                                    breadcrumbIndex == _breadcrumbs.length - 1;

                                return InkWell(
                                  onTap: isLast
                                      ? null
                                      : () {
                                          setState(() {
                                            _breadcrumbs = _breadcrumbs.sublist(
                                                0, breadcrumbIndex + 1);
                                            _currentCategories =
                                                _categoriesByParent[
                                                        category['id']] ??
                                                    [];
                                          });
                                        },
                                  child: Text(
                                    category['name'],
                                    style: TextStyle(
                                      color: isLast
                                          ? Colors.grey[800]
                                          : const Color(0xFF4B88DA),
                                      fontWeight: isLast
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),

                      // Liste des catégories
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _currentCategories.length,
                          itemBuilder: (context, index) {
                            final category = _currentCategories[index];
                            final hasSubcategories =
                                _categoriesByParent.containsKey(category['id']);
                            final isSelected =
                                _selectedCategories.contains(category['id']);

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 0),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category['name'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF4B88DA)
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedCategories
                                              .add(category['id']);
                                        } else {
                                          _selectedCategories
                                              .remove(category['id']);
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF4B88DA),
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (hasSubcategories) {
                                  setState(() {
                                    _breadcrumbs.add(category);
                                    _currentCategories =
                                        _categoriesByParent[category['id']] ??
                                            [];
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4B88DA),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _resetProducts();
                          },
                          child: const Text(
                            'Appliquer',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _sortProducts() {
    setState(() {
      switch (_currentSort) {
        case SortOption.priceAsc:
          _products.sort((a, b) => a.finalPrice.compareTo(b.finalPrice));
          break;
        case SortOption.priceDesc:
          _products.sort((a, b) => b.finalPrice.compareTo(a.finalPrice));
          break;
        case SortOption.newest:
          // Utiliser directement la requête Firestore pour le tri par date
          break;
        case SortOption.distance:
          // Le tri par distance sera fait après avoir récupéré les informations des entreprises
          break;
      }
    });
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
    if (widget.userLat == null ||
        widget.userLng == null ||
        !address.containsKey('latitude') ||
        !address.containsKey('longitude')) {
      return null;
    }

    final companyLat = address['latitude'] as double;
    final companyLng = address['longitude'] as double;

    const double earthRadius = 6371;
    final latDiff = _degreesToRadians(companyLat - widget.userLat!);
    final lngDiff = _degreesToRadians(companyLng - widget.userLng!);

    final a = sin(latDiff / 2) * sin(latDiff / 2) +
        cos(_degreesToRadians(widget.userLat!)) *
            cos(_degreesToRadians(companyLat)) *
            sin(lngDiff / 2) *
            sin(lngDiff / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: widget.title,
        align: Alignment.center,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _showCategoriesBottomSheet,
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedCompanies.isNotEmpty ||
                    _currentSort != SortOption.newest ||
                    _selectedCategories.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4B88DA),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              _showSortFilterBottomSheet();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre des filtres actifs
          if (_selectedCompanies.isNotEmpty ||
              _currentSort != SortOption.newest ||
              _selectedCategories.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Afficher les catégories sélectionnées
                    ..._selectedCategories.map((categoryId) {
                      final category = _categories.firstWhere(
                        (c) => c['id'] == categoryId,
                        orElse: () => {'name': '', 'icon': ''},
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category['name']),
                          onSelected: (_) {},
                          onDeleted: () {
                            setState(() {
                              _selectedCategories.remove(categoryId);
                            });
                            _resetProducts();
                          },
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      );
                    }),

                    // Afficher le filtre de tri actif
                    if (_currentSort != SortOption.newest)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            _currentSort == SortOption.priceAsc
                                ? 'Prix croissant'
                                : _currentSort == SortOption.priceDesc
                                    ? 'Prix décroissant'
                                    : _currentSort == SortOption.distance
                                        ? 'Distance'
                                        : 'Plus récents',
                          ),
                          onSelected: (_) {},
                          onDeleted: () {
                            setState(() {
                              _currentSort = SortOption.newest;
                            });
                            _resetProducts();
                          },
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),

                    // Afficher les entreprises sélectionnées
                    ..._selectedCompanies.map((companyId) {
                      final company = _companies.firstWhere(
                        (c) => c['id'] == companyId,
                        orElse: () => {'name': '', 'logo': ''},
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: company['logo'].isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage:
                                      NetworkImage(company['logo']),
                                  radius: 12,
                                )
                              : null,
                          label: Text(company['name']),
                          onSelected: (_) {},
                          onDeleted: () {
                            setState(() {
                              _selectedCompanies.remove(companyId);
                            });
                            _resetProducts();
                          },
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      );
                    }),

                    // Bouton pour tout effacer
                    if (_selectedCompanies.isNotEmpty ||
                        _currentSort != SortOption.newest ||
                        _selectedCategories.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCompanies.clear();
                            _currentSort = SortOption.newest;
                            _selectedCategories.clear();
                          });
                          _resetProducts();
                        },
                        child: const Text(
                          'Tout effacer',
                          style: TextStyle(
                            color: Color(0xFF4B88DA),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Contenu principal modifié
          Expanded(
            child: _products.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty && !_hasMore
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun produit disponible',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: _buildProductsGrid(_products),
                          ),
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(List<Product> products) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('companys')
              .doc(product.sellerId)
              .get(),
          builder: (context, companySnapshot) {
            if (!companySnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final companyData =
                companySnapshot.data!.data() as Map<String, dynamic>;
            final companyName = companyData['name'] as String;
            final companyLogo = companyData['logo'] as String;
            final address = companyData['adress'] as Map<String, dynamic>?;

            double? distance;
            if (widget.showDistance && address != null) {
              distance = _calculateDistance(address);
            }

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ModernProductDetailPage(
                      product: product,
                    ),
                  ),
                );
              },
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              image: DecorationImage(
                                image: NetworkImage(
                                  product.images.isNotEmpty
                                      ? product.images[0]
                                      : 'URL_IMAGE_PAR_DEFAUT',
                                ),
                                fit: BoxFit.cover,
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
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                '${product.price.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
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
                                '${product.price.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            const Spacer(),
                            Row(
                              children: [
                                if (companyLogo.isNotEmpty)
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundImage: NetworkImage(companyLogo),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        companyName,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (distance != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 12,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              _formatDistance(distance),
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
