import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/category_product.dart';

class FilterBottomSheet extends StatefulWidget {
  final Category? selectedMainCategory;
  final Category? selectedSubCategory;
  final Map<String, String> selectedAttributes;
  final List<CategoryAttribute> availableAttributes;
  final Function(Category?, Category?) onCategorySelected;
  final Function(Map<String, String>) onAttributesChanged;

  const FilterBottomSheet({
    super.key,
    this.selectedMainCategory,
    this.selectedSubCategory,
    required this.selectedAttributes,
    required this.availableAttributes,
    required this.onCategorySelected,
    required this.onAttributesChanged,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  Category? _currentCategory;
  Category? _selectedMainCategory;
  Category? _selectedSubCategory;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.selectedMainCategory;
    _selectedMainCategory = widget.selectedMainCategory;
    _selectedSubCategory = widget.selectedSubCategory;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCategories(),
                  if (widget.availableAttributes.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    _buildAttributes(),
                  ],
                ],
              ),
            ),
            _buildApplyButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Filtres',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          TextButton(
            onPressed: () {
              widget.onCategorySelected(null, null);
              widget.onAttributesChanged({});
              Navigator.pop(context);
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final Query query = FirebaseFirestore.instance.collection('categories');

    print('Current category ID: ${_currentCategory?.id}');
    print('Selected Main Category: ${_selectedMainCategory?.id}');
    print('Selected Sub Category: ${_selectedSubCategory?.id}');

    final Stream<QuerySnapshot> stream = _currentCategory != null
        ? query.where('parentId', isEqualTo: _currentCategory!.id).snapshots()
        : query.where('level', isEqualTo: 1).snapshots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentCategory != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () {
                if (_currentCategory?.parentId != null) {
                  FirebaseFirestore.instance
                      .collection('categories')
                      .doc(_currentCategory!.parentId)
                      .get()
                      .then((doc) {
                    if (doc.exists) {
                      setState(() {
                        _currentCategory = Category.fromFirestore(doc);
                      });
                    } else {
                      setState(() {
                        _currentCategory = null;
                      });
                    }
                  });
                } else {
                  setState(() {
                    _currentCategory = null;
                  });
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.arrow_back, size: 20),
                  const SizedBox(width: 8),
                  Text(_currentCategory!.name,
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final categories = snapshot.data!.docs
                .map((doc) => Category.fromFirestore(doc))
                .toList();

            if (categories.isEmpty && _currentCategory != null) {
              final isSelected =
                  _currentCategory!.id == _selectedSubCategory?.id;
              return ListTile(
                title: Text(_currentCategory!.name),
                trailing: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedSubCategory = _currentCategory;
                  });
                },
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category.id == _selectedSubCategory?.id;

                return ListTile(
                  title: Text(category.name),
                  trailing: const Icon(Icons.chevron_right),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _currentCategory = category;
                      _selectedMainCategory ??= category;
                    });
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttributes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.availableAttributes
          .map((attr) => _buildAttributeSection(attr))
          .toList(),
    );
  }

  Widget _buildAttributeSection(CategoryAttribute attr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(attr.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: attr.values.map((value) {
            final isSelected = widget.selectedAttributes[attr.name] == value;
            return FilterChip(
              label: Text(value),
              selected: isSelected,
              onSelected: (selected) {
                final newAttributes =
                    Map<String, String>.from(widget.selectedAttributes);
                if (selected) {
                  newAttributes[attr.name] = value;
                } else {
                  newAttributes.remove(attr.name);
                }
                widget.onAttributesChanged(newAttributes);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildApplyButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          widget.onCategorySelected(
              _selectedMainCategory, _selectedSubCategory);
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        child: const Text('Appliquer les filtres'),
      ),
    );
  }
}
