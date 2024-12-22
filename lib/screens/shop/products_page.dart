import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/category_product.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/widgets/filter_bottom_sheet.dart';

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

    if (selectedSubCategory != null) {
      productsQuery = productsQuery.where('categoryPath',
          arrayContains: selectedSubCategory!.id);
    } else if (selectedMainCategory != null) {
      productsQuery = productsQuery.where('categoryPath',
          arrayContains: selectedMainCategory!.id);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: productsQuery.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: CircularProgressIndicator(),
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

        if (products.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Text('Aucun produit trouvé'),
            ),
          );
        }

        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ModernProductDetailPage(product: product)),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image du produit
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  image: mainVariant.images.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(mainVariant.images[0]),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),
            ),

            // Informations du produit
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mainVariant.price.toStringAsFixed(2)}€',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Informations du vendeur
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

                      return Row(
                        children: [
                          if (company['logo'] != null)
                            Container(
                              width: 20,
                              height: 20,
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
                            child: Text(
                              company['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
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
