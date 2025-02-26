import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/category_product.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/widgets/product_card.dart';

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
  Map<String, List<String>> selectedAttributes = {};
  List<String> selectedCompanies = [];
  List<CategoryAttribute> availableAttributes = [];
  bool isLoading = false;

  // Variables temporaires pour les filtres
  Category? tempMainCategory;
  Category? tempSubCategory;
  Category? tempSubCategory2;
  Category? tempSubCategory3;
  Map<String, List<String>> tempAttributes = {};
  List<String> tempSelectedCompanies = [];

  @override
  void initState() {
    super.initState();
    _resetTempValues();
  }

  void _resetTempValues() {
    tempMainCategory = selectedMainCategory;
    tempSubCategory = selectedSubCategory;
    tempSubCategory2 = selectedSubCategory2;
    tempSubCategory3 = selectedSubCategory3;
    tempAttributes = Map.from(selectedAttributes);
    tempSelectedCompanies = List.from(selectedCompanies);
  }

  void _applyFilters() {
    setState(() {
      selectedMainCategory = tempMainCategory;
      selectedSubCategory = tempSubCategory;
      selectedSubCategory2 = tempSubCategory2;
      selectedSubCategory3 = tempSubCategory3;
      selectedAttributes = Map.from(tempAttributes);
      selectedCompanies = List.from(tempSelectedCompanies);
      _updateProductsList();
    });
  }

  void _cancelFilters() {
    setState(() {
      _resetTempValues();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.business,
              color:
                  selectedCompanies.isNotEmpty ? const Color(0xFF4B88DA) : null,
            ),
            onPressed: _showCompaniesBottomSheet,
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color:
                  selectedMainCategory != null || selectedAttributes.isNotEmpty
                      ? const Color(0xFF4B88DA)
                      : null,
            ),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (selectedMainCategory != null ||
              selectedCompanies.isNotEmpty ||
              selectedAttributes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildActiveFilters(),
            ),
          Expanded(
            child: _buildProductsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Filtres de catégories
          if (selectedMainCategory != null) ...[
            FilterChip(
              label: Text(selectedMainCategory!.name),
              onSelected: (_) {},
              onDeleted: () {
                setState(() {
                  selectedMainCategory = null;
                  selectedSubCategory = null;
                  selectedSubCategory2 = null;
                  selectedSubCategory3 = null;
                  selectedAttributes.clear();
                  _updateProductsList();
                });
              },
              labelStyle: const TextStyle(color: Colors.white),
              backgroundColor: Colors.blue[800],
            ),
            const SizedBox(width: 8),
          ],
          if (selectedSubCategory != null) ...[
            FilterChip(
              label: Text(selectedSubCategory!.name),
              onSelected: (_) {},
              onDeleted: () {
                setState(() {
                  selectedSubCategory = null;
                  selectedSubCategory2 = null;
                  selectedSubCategory3 = null;
                  selectedAttributes.clear();
                  _updateProductsList();
                });
              },
              labelStyle: const TextStyle(color: Colors.white),
              backgroundColor: Colors.blue[800],
            ),
            const SizedBox(width: 8),
          ],
          if (selectedSubCategory2 != null) ...[
            FilterChip(
              label: Text(selectedSubCategory2!.name),
              onSelected: (_) {},
              onDeleted: () {
                setState(() {
                  selectedSubCategory2 = null;
                  selectedSubCategory3 = null;
                  selectedAttributes.clear();
                  _updateProductsList();
                });
              },
              labelStyle: const TextStyle(color: Colors.white),
              backgroundColor: Colors.blue[800],
            ),
            const SizedBox(width: 8),
          ],
          if (selectedSubCategory3 != null) ...[
            FilterChip(
              label: Text(selectedSubCategory3!.name),
              onSelected: (_) {},
              onDeleted: () {
                setState(() {
                  selectedSubCategory3 = null;
                  selectedAttributes.clear();
                  _updateProductsList();
                });
              },
              labelStyle: const TextStyle(color: Colors.white),
              backgroundColor: Colors.blue[800],
            ),
            const SizedBox(width: 8),
          ],

          // Filtres d'entreprises
          ...selectedCompanies.map((companyId) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('companys')
                  .doc(companyId)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final companyData =
                    snapshot.data!.data() as Map<String, dynamic>;
                final companyName = companyData['name'] as String;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: CircleAvatar(
                      backgroundImage:
                          NetworkImage(companyData['logo'] as String),
                      backgroundColor: Colors.grey[200],
                    ),
                    label: Text(companyName),
                    onSelected: (_) {},
                    onDeleted: () {
                      setState(() {
                        selectedCompanies.remove(companyId);
                        _updateProductsList();
                      });
                    },
                    labelStyle: const TextStyle(color: Colors.white),
                    backgroundColor: Colors.blue[800],
                  ),
                );
              },
            );
          }),

          // Filtres d'attributs
          ...selectedAttributes.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${entry.key}: ${entry.value.join(", ")}'),
                onSelected: (_) {},
                onDeleted: () {
                  setState(() {
                    selectedAttributes.remove(entry.key);
                    _updateProductsList();
                  });
                },
                labelStyle: const TextStyle(color: Colors.white),
                backgroundColor: Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    Query<Map<String, dynamic>> productsQuery =
        FirebaseFirestore.instance.collection('products');

    // Appliquer le filtre de catégorie
    Category? selectedCategory;
    if (selectedSubCategory3 != null) {
      selectedCategory = selectedSubCategory3;
    } else if (selectedSubCategory2 != null) {
      selectedCategory = selectedSubCategory2;
    } else if (selectedSubCategory != null) {
      selectedCategory = selectedSubCategory;
    } else if (selectedMainCategory != null) {
      selectedCategory = selectedMainCategory;
    }

    if (selectedCategory != null) {
      productsQuery = productsQuery.where('categoryPath',
          arrayContains: selectedCategory.id);
    }

    // Appliquer le filtre d'entreprises
    if (selectedCompanies.isNotEmpty) {
      productsQuery =
          productsQuery.where('sellerId', whereIn: selectedCompanies);
    }

    // Appliquer les filtres d'attributs
    if (selectedAttributes.isNotEmpty) {
      for (var entry in selectedAttributes.entries) {
        productsQuery = productsQuery.where(
          'variants.attributes.${entry.key}',
          whereIn: entry.value,
        );
      }
    }

    return StreamBuilder<QuerySnapshot>(
      stream: productsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Aucun produit ne correspond à vos critères',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }

        final products = snapshot.data!.docs;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isTabletOrDesktop = constraints.maxWidth > 600;
            final crossAxisCount = isTabletOrDesktop ? 3 : 2;
            final horizontalPadding = isTabletOrDesktop ? 24.0 : 16.0;
            final spacing = isTabletOrDesktop ? 20.0 : 12.0;
            final availableWidth = constraints.maxWidth -
                (2 * horizontalPadding) -
                (spacing * (crossAxisCount - 1));
            final cardWidth = availableWidth / crossAxisCount;
            final childAspectRatio = cardWidth / (cardWidth * 1.45);

            return GridView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: spacing,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = Product.fromFirestore(products[index]);
                return ProductCard(
                  product: product,
                  width: cardWidth,
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _loadAttributes(String categoryId) async {
    setState(() => isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('categoryAttributes')
          .doc(categoryId)
          .get();

      if (!doc.exists) {
        setState(() {
          availableAttributes = [];
          isLoading = false;
        });
        return;
      }

      final categoryAttributes = CategoryAttributes.fromFirestore(doc);

      setState(() {
        availableAttributes = categoryAttributes.attributes;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading attributes: $e');
      setState(() {
        availableAttributes = [];
        isLoading = false;
      });
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Catégories',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  tempMainCategory = null;
                                  tempSubCategory = null;
                                  tempSubCategory2 = null;
                                  tempSubCategory3 = null;
                                  tempAttributes.clear();
                                });
                              },
                              child: const Text('Réinitialiser'),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            if (tempMainCategory == null)
                              _buildMainCategories(setModalState)
                            else if (tempSubCategory == null)
                              _buildSubCategories(
                                  tempMainCategory!, setModalState)
                            else if (tempSubCategory2 == null)
                              _buildSubCategories2(
                                  tempMainCategory!, setModalState)
                            else if (tempSubCategory3 == null)
                              _buildSubCategories3(
                                  tempSubCategory2!, setModalState)
                            else
                              _buildAttributesSection(),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, -4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _cancelFilters();
                                  Navigator.pop(context);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(
                                      color: Color(0xFF4B88DA)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Annuler'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _applyFilters();
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4B88DA),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Appliquer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  void _updateProductsList() {
    Query<Map<String, dynamic>> productsQuery =
        FirebaseFirestore.instance.collection('products');

    // Déterminer la catégorie la plus spécifique sélectionnée
    Category? selectedCategory;
    if (selectedSubCategory3 != null) {
      selectedCategory = selectedSubCategory3;
    } else if (selectedSubCategory2 != null) {
      selectedCategory = selectedSubCategory2;
    } else if (selectedSubCategory != null) {
      selectedCategory = selectedSubCategory;
    } else if (selectedMainCategory != null) {
      selectedCategory = selectedMainCategory;
    }

    // Appliquer le filtre de catégorie
    if (selectedCategory != null) {
      productsQuery = productsQuery.where('categoryPath',
          arrayContains: selectedCategory.id);
    }

    // Appliquer le filtre d'entreprises
    if (selectedCompanies.isNotEmpty) {
      productsQuery =
          productsQuery.where('sellerId', whereIn: selectedCompanies);
    }

    // Appliquer les filtres d'attributs
    if (selectedAttributes.isNotEmpty) {
      for (var entry in selectedAttributes.entries) {
        productsQuery = productsQuery.where(
          'variants.attributes.${entry.key}',
          whereIn: entry.value,
        );
      }
    }

    setState(() {
      // Le StreamBuilder se mettra à jour automatiquement avec la nouvelle requête
    });
  }

  Widget _buildMainCategories(StateSetter setModalState) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('level', isEqualTo: 1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              title: Text(category.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setModalState(() {
                  tempMainCategory = category;
                });
                if (category.hasAttributes) {
                  _loadAttributes(category.id);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSubCategories(
      Category parentCategory, StateSetter setModalState) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('parentId', isEqualTo: parentCategory.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setModalState(() {
                  tempMainCategory = null;
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  title: Text(category.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setModalState(() {
                      tempSubCategory = category;
                    });
                    if (category.hasAttributes) {
                      _loadAttributes(category.id);
                    }
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubCategories2(
      Category parentCategory, StateSetter setModalState) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('parentId', isEqualTo: parentCategory.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setModalState(() {
                  tempSubCategory = null;
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: Text('Retour à ${tempMainCategory?.name ?? ""}'),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  title: Text(category.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setModalState(() {
                      tempSubCategory2 = category;
                    });
                    if (category.hasAttributes) {
                      _loadAttributes(category.id);
                    }
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubCategories3(
      Category parentCategory, StateSetter setModalState) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('parentId', isEqualTo: parentCategory.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () {
                setModalState(() {
                  tempSubCategory2 = null;
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: Text('Retour à ${tempSubCategory?.name ?? ""}'),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  title: Text(category.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setModalState(() {
                      tempSubCategory3 = category;
                    });
                    if (category.hasAttributes) {
                      _loadAttributes(category.id);
                    }
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttributesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: availableAttributes.map((attribute) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attribute.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attribute.values.map((value) {
                final isSelected =
                    selectedAttributes[attribute.name]?.contains(value) ??
                        false;
                return FilterChip(
                  selected: isSelected,
                  label: Text(value),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Colors.grey[200],
                  selectedColor: Colors.blue[800],
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (selectedAttributes[attribute.name] == null) {
                          selectedAttributes[attribute.name] = [];
                        }
                        selectedAttributes[attribute.name]!.add(value);
                      } else {
                        selectedAttributes[attribute.name]!.remove(value);
                      }
                    });
                  },
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.blue[800]! : Colors.grey[300]!,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
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
                            _loadAttributes(selectedCategory.id);
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

  void _showCompaniesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Entreprises',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSelectedCompanies.clear();
                            });
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('companys')
                          .where('sellerId', isNull: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final companies = snapshot.data!.docs;

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: companies.length,
                          itemBuilder: (context, index) {
                            final company = companies[index];
                            final companyData =
                                company.data() as Map<String, dynamic>;
                            final companyName = companyData['name'] as String;
                            final companyLogo = companyData['logo'] as String;
                            final isSelected =
                                tempSelectedCompanies.contains(company.id);

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(companyLogo),
                                backgroundColor: Colors.grey[200],
                              ),
                              title: Text(companyName),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Color(0xFF4B88DA))
                                  : const Icon(Icons.circle_outlined),
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    tempSelectedCompanies.remove(company.id);
                                  } else {
                                    tempSelectedCompanies.add(company.id);
                                  }
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, -4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              _cancelFilters();
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFF4B88DA)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _applyFilters();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B88DA),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Appliquer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
