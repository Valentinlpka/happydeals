import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/category_product.dart';
import 'package:happy/screens/match_market/match_market_swipe_page.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';

class MatchMarketIntroPage extends StatefulWidget {
  const MatchMarketIntroPage({super.key});

  @override
  State<MatchMarketIntroPage> createState() => _MatchMarketIntroPageState();
}

class _MatchMarketIntroPageState extends State<MatchMarketIntroPage> {
  Category? selectedCategory;
  Category? selectedSubCategory;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarBack(title: 'Match Market'),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Trouvez vos produits préférés',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            Expanded(
              child: _buildCategorySelection(),
            ),
            if (selectedSubCategory != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchMarketSwipePage(
                          category: selectedSubCategory!,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Commencer'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectedCategory == null) ...[
            const Text(
              'Choisissez une catégorie',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMainCategories(),
          ] else ...[
            InkWell(
              onTap: () {
                setState(() {
                  selectedCategory = null;
                  selectedSubCategory = null;
                });
              },
              child: Row(
                children: [
                  const Icon(Icons.arrow_back),
                  const SizedBox(width: 8),
                  Text(
                    selectedCategory!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSubCategories(),
          ],
        ],
      ),
    );
  }

  Widget _buildMainCategories() {
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

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              title: Text(category.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  selectedCategory = category;
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSubCategories() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('parentId', isEqualTo: selectedCategory!.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();

        if (categories.isEmpty) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedSubCategory = selectedCategory;
                });
              },
              child: const Text('Sélectionner cette catégorie'),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = selectedSubCategory?.id == category.id;

            return ListTile(
              title: Text(category.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).primaryColor,
                    )
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                setState(() {
                  selectedCategory = category;
                  selectedSubCategory = null;
                });
              },
              selected: isSelected,
            );
          },
        );
      },
    );
  }
}
