import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/category_product.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/widgets/filter_bottom_sheet.dart';

String formatCategoryName(String categoryId) {
  if (categoryId.isEmpty) return '';

  // Remplacer les underscores par des espaces
  String name = categoryId.replaceAll('_', ' ');

  // Capitaliser chaque mot
  List<String> words = name.split(' ');
  words = words.map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).toList();

  return words.join(' ');
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  Category? selectedMainCategory;
  Category? selectedSubCategory;
  Category? selectedSubCategory2;
  Category? selectedSubCategory3;
  Map<String, String> selectedAttributes = {};
  List<CategoryAttribute> availableAttributes = [];
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            pinned: true,
            title: Text('Produits'),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),

          // Une seule liste horizontale pour toutes les catégories
          SliverToBoxAdapter(
            child: _buildSelectedCategoriesRow(),
          ),

          // Liste des produits
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _buildProductsGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubcategoriesSheet(
            selectedMainCategory ??
                Category(id: '', name: 'Catégories', level: 1),
            level: selectedMainCategory == null ? 1 : 2),
        child: const Icon(Icons.category),
      ),
    );
  }

  Widget _buildSelectedCategoriesRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('level', isEqualTo: 1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 50);
        }

        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();

        return Container(
          height: 50,
          color: Colors.white,
          child: StreamBuilder<QuerySnapshot>(
            stream: selectedMainCategory != null
                ? FirebaseFirestore.instance
                    .collection('categories')
                    .where('parentId', isEqualTo: selectedMainCategory!.id)
                    .snapshots()
                : null,
            builder: (context, subSnapshot1) {
              return StreamBuilder<QuerySnapshot>(
                stream: selectedSubCategory != null
                    ? FirebaseFirestore.instance
                        .collection('categories')
                        .where('parentId', isEqualTo: selectedSubCategory!.id)
                        .snapshots()
                    : null,
                builder: (context, subSnapshot2) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: selectedSubCategory2 != null
                        ? FirebaseFirestore.instance
                            .collection('categories')
                            .where('parentId',
                                isEqualTo: selectedSubCategory2!.id)
                            .snapshots()
                        : null,
                    builder: (context, subSnapshot3) {
                      List<Widget> chips = [
                        // Niveau 1
                        ...categories.map((category) => _buildCategoryChip(
                              category,
                              isSelected:
                                  selectedMainCategory?.id == category.id,
                              onSelected: (selected) {
                                setState(() {
                                  selectedMainCategory =
                                      selected ? category : null;
                                  selectedSubCategory = null;
                                  selectedSubCategory2 = null;
                                  selectedSubCategory3 = null;
                                  if (category.hasAttributes) {
                                    _loadAttributes(category);
                                  }
                                });
                              },
                            )),
                      ];

                      // Niveau 2
                      if (selectedMainCategory != null &&
                          subSnapshot1.hasData) {
                        final subCategories = subSnapshot1.data!.docs
                            .map((doc) => Category.fromFirestore(doc))
                            .toList();
                        chips.addAll(
                            subCategories.map((category) => _buildCategoryChip(
                                  category,
                                  isSelected:
                                      selectedSubCategory?.id == category.id,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedSubCategory =
                                          selected ? category : null;
                                      selectedSubCategory2 = null;
                                      selectedSubCategory3 = null;
                                      if (category.hasAttributes) {
                                        _loadAttributes(category);
                                      }
                                    });
                                  },
                                )));
                      }

                      // Niveau 3
                      if (selectedSubCategory != null && subSnapshot2.hasData) {
                        final subCategories = subSnapshot2.data!.docs
                            .map((doc) => Category.fromFirestore(doc))
                            .toList();
                        chips.addAll(
                            subCategories.map((category) => _buildCategoryChip(
                                  category,
                                  isSelected:
                                      selectedSubCategory2?.id == category.id,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedSubCategory2 =
                                          selected ? category : null;
                                      selectedSubCategory3 = null;
                                      if (category.hasAttributes) {
                                        _loadAttributes(category);
                                      }
                                    });
                                  },
                                )));
                      }

                      // Niveau 4
                      if (selectedSubCategory2 != null &&
                          subSnapshot3.hasData) {
                        final subCategories = subSnapshot3.data!.docs
                            .map((doc) => Category.fromFirestore(doc))
                            .toList();
                        chips.addAll(
                            subCategories.map((category) => _buildCategoryChip(
                                  category,
                                  isSelected:
                                      selectedSubCategory3?.id == category.id,
                                  onSelected: (selected) {
                                    setState(() {
                                      selectedSubCategory3 =
                                          selected ? category : null;
                                      if (category.hasAttributes) {
                                        _loadAttributes(category);
                                      }
                                    });
                                  },
                                )));
                      }

                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: chips,
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(
    Category category, {
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(
          category.name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: Colors.transparent,
        selectedColor: Colors.blue[800],
        checkmarkColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.blue[800]! : Colors.grey[300]!,
          ),
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    Query productsQuery = FirebaseFirestore.instance.collection('products');

    // Filtrer par catégorie si une est sélectionnée
    if (selectedSubCategory3 != null) {
      productsQuery = productsQuery.where('categoryPath',
          arrayContains: selectedSubCategory3!.id);
    } else if (selectedSubCategory2 != null) {
      productsQuery = productsQuery.where('categoryPath',
          arrayContains: selectedSubCategory2!.id);
    } else if (selectedSubCategory != null) {
      productsQuery = productsQuery.where('categoryPath',
          arrayContains: selectedSubCategory!.id);
    } else if (selectedMainCategory != null) {
      productsQuery = productsQuery.where('categoryPath',
          arrayContains: selectedMainCategory!.id);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: productsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text('Erreur: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Text(
                'Aucun produit trouvé',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          );
        }

        var products = snapshot.data!.docs
            .map((doc) => Product.fromFirestore(doc))
            .where((product) {
          if (selectedAttributes.isEmpty) return true;

          return product.variants.any((variant) {
            return selectedAttributes.entries.every((attr) {
              return variant.attributes[attr.key] == attr.value;
            });
          });
        }).toList();

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildProductCard(products[index]),
            childCount: products.length,
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final mainVariant =
        product.variants.isNotEmpty ? product.variants[0] : null;
    if (mainVariant == null) return const SizedBox();

    final hasMultipleVariants = product.variants.length > 1;

    // On prend en priorité la réduction de la variante, sinon celle du produit
    final activeDiscount = mainVariant.discount?.isValid() ?? false
        ? mainVariant.discount
        : product.discount?.isValid() ?? false
            ? product.discount
            : null;

    final hasDiscount = activeDiscount != null;

    // Calculer le prix final avec une seule réduction
    double finalPrice = mainVariant.price;
    if (hasDiscount) {
      finalPrice = activeDiscount.calculateDiscountedPrice(finalPrice);
    }

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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image et badges
              Stack(
                children: [
                  // Image
                  AspectRatio(
                    aspectRatio: 1,
                    child: mainVariant.images.isNotEmpty
                        ? Hero(
                            tag: 'product-${product.id}',
                            child: Image.network(
                              mainVariant.images[0],
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),

                  // Overlay gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.3),
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                          ],
                          stops: const [0.0, 0.3, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Badges en haut
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badges à gauche
                        Row(
                          children: [
                            if (hasDiscount)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '-${((1 - finalPrice / mainVariant.price) * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (hasMultipleVariants)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.style,
                                      size: 12,
                                      color: Colors.grey[800],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${product.variants.length} options',
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        // Bouton favoris
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_border,
                            size: 20,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Prix en bas
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDiscount) ...[
                          Text(
                            '${finalPrice.toStringAsFixed(2)}€',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${mainVariant.price.toStringAsFixed(2)}€',
                            style: TextStyle(
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ] else
                          Text(
                            '${mainVariant.price.toStringAsFixed(2)}€',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Informations produit
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Catégorie
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('categories')
                          .doc(product.categoryId)
                          .get(),
                      builder: (context, snapshot) {
                        String categoryName = '';
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final categoryData =
                              snapshot.data!.data() as Map<String, dynamic>;
                          categoryName = categoryData['name'] as String? ?? '';
                        } else {
                          categoryName =
                              formatCategoryName(product.categoryId ?? '');
                        }

                        return Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),

                    // Nom du produit
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Stock
                    if (mainVariant.stock <= 5)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: mainVariant.stock > 0
                              ? Colors.orange.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mainVariant.stock > 0
                              ? 'Plus que ${mainVariant.stock} en stock'
                              : 'Rupture de stock',
                          style: TextStyle(
                            fontSize: 12,
                            color: mainVariant.stock > 0
                                ? Colors.orange[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    // Séparateur
                    const Divider(),

                    // Vendeur
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('companys')
                          .doc(product.sellerId)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        final company =
                            snapshot.data!.data() as Map<String, dynamic>?;
                        if (company == null) return const SizedBox();

                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailsEntreprise(
                                  entrepriseId: product.sellerId,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              if (company['logo'] != null)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: NetworkImage(company['logo']),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Vendu par',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      company['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        );
                      },
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

  Future<void> _loadAttributes(Category category) async {
    if (!category.hasAttributes) {
      setState(() => availableAttributes = []);
      return;
    }

    setState(() => isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('categoryAttributes')
          .doc(category.id)
          .get();

      if (doc.exists) {
        final categoryAttributes = CategoryAttributes.fromFirestore(doc);
        setState(() => availableAttributes = categoryAttributes.attributes);
      } else {
        setState(() => availableAttributes = []);
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des attributs: $e');
      setState(() => availableAttributes = []);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterBottomSheet(
        selectedMainCategory: selectedMainCategory,
        selectedSubCategory: selectedSubCategory,
        selectedAttributes: selectedAttributes,
        availableAttributes: availableAttributes,
        onCategorySelected: (mainCategory, subCategory) {
          setState(() {
            selectedMainCategory = mainCategory;
            selectedSubCategory = subCategory;
            if (subCategory != null) {
              _loadAttributes(subCategory);
            } else if (mainCategory != null) {
              _loadAttributes(mainCategory);
            }
          });
        },
        onAttributesChanged: (newAttributes) {
          setState(() {
            selectedAttributes = newAttributes;
          });
        },
      ),
    );
  }

  void _showSubcategoriesSheet(Category parentCategory, {int level = 1}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barre de titre
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Catégories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Liste des sous-catégories
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: _buildCategoryList(
                      parentCategory,
                      level,
                      (selectedCategory) {
                        setState(() {
                          if (level == 1) {
                            selectedMainCategory = selectedCategory;
                            selectedSubCategory = null;
                          } else {
                            selectedSubCategory = selectedCategory;
                          }

                          if (selectedCategory != null) {
                            _loadAttributes(selectedCategory);
                          }
                        });
                        Navigator.pop(context);
                      },
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

  Widget _buildCategoryList(
    Category parentCategory,
    int currentLevel,
    Function(Category?) onSelect,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('parentId', isEqualTo: parentCategory.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final subCategories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();

        return Column(
          children: [
            // Bouton pour sélectionner la catégorie courante
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => onSelect(parentCategory),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Sélectionner ${parentCategory.name}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            if (subCategories.isNotEmpty && currentLevel < 4)
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: subCategories.length,
                  itemBuilder: (context, index) {
                    final subCategory = subCategories[index];
                    return ListTile(
                      title: Text(
                        subCategory.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: currentLevel < 3
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: () {
                        if (currentLevel == 3) {
                          // Au niveau 3, sélectionner directement la catégorie
                          onSelect(subCategory);
                        } else {
                          // Sinon, naviguer vers le niveau suivant
                          Navigator.pop(context);
                          _showSubcategoriesSheet(
                            subCategory,
                            level: currentLevel + 1,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
