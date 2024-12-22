import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/category_product.dart';

class SubcategoriesSheet extends StatefulWidget {
  final Category parentCategory;
  final Function(Category?) onCategorySelected;

  const SubcategoriesSheet({
    super.key,
    required this.parentCategory,
    required this.onCategorySelected,
  });

  @override
  State<SubcategoriesSheet> createState() => _SubcategoriesSheetState();
}

class _SubcategoriesSheetState extends State<SubcategoriesSheet> {
  List<Category> _categoryPath = [];

  @override
  void initState() {
    super.initState();
    _categoryPath = [widget.parentCategory];
    _loadSubcategories(widget.parentCategory);
  }

  Future<void> _loadSubcategories(Category category) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .where('parentId', isEqualTo: category.id)
        .get();

    if (mounted) {
      setState(() {
        final subcategories =
            snapshot.docs.map((doc) => Category.fromFirestore(doc)).toList();

        if (subcategories.isNotEmpty) {
          _categoryPath.add(subcategories.first);
          _loadSubcategories(subcategories.first);
        }
      });
    }
  }

  Widget _buildCategoryList() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _categoryPath.length,
            itemBuilder: (context, index) {
              final category = _categoryPath[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      index == 0
                          ? 'Catégorie principale'
                          : 'Sous-catégorie niveau $index',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('categories')
                        .where('parentId', isEqualTo: category.parentId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final categories = snapshot.data!.docs
                          .map((doc) => Category.fromFirestore(doc))
                          .toList();

                      return Column(
                        children: categories
                            .map((cat) => ListTile(
                                  title: Text(cat.name),
                                  selected: _categoryPath[index].id == cat.id,
                                  onTap: () {
                                    setState(() {
                                      // Mettre à jour le chemin à partir de ce niveau
                                      _categoryPath =
                                          _categoryPath.sublist(0, index);
                                      _categoryPath.add(cat);
                                      widget.onCategorySelected(cat);
                                    });
                                    _loadSubcategories(cat);
                                  },
                                ))
                            .toList(),
                      );
                    },
                  ),
                  const Divider(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildBreadcrumbs(),
          Expanded(child: _buildCategoryList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_categoryPath.length > 1) {
                setState(() {
                  _categoryPath.removeLast();
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(width: 8),
          Text(
            _categoryPath.last.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _categoryPath.map((category) {
          final isLast = category == _categoryPath.last;
          return Row(
            children: [
              GestureDetector(
                onTap: isLast ? null : () => _navigateToCategory(category),
                child: Text(
                  category.name,
                  style: TextStyle(
                    color: isLast ? Colors.black : Colors.blue,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.chevron_right, size: 16),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _navigateToCategory(Category category) {
    setState(() {
      _categoryPath =
          _categoryPath.sublist(0, _categoryPath.indexOf(category) + 1);
    });
  }
}
