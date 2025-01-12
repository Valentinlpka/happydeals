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
  List<Category> categoryPath = [];
  int currentLevel = 1;

  void _goToNextLevel(Category category) {
    setState(() {
      selectedCategory = category;
      categoryPath.add(category);
      currentLevel++;
    });
  }

  void _goToPreviousLevel() {
    setState(() {
      currentLevel--;
      categoryPath.removeLast();
      if (categoryPath.isEmpty) {
        selectedCategory = null;
      } else {
        selectedCategory = categoryPath.last;
      }
    });
  }

  String _getPreviousLevelText() {
    if (categoryPath.isEmpty || categoryPath.length < 2) {
      return 'Retour au niveau précédent';
    }
    return categoryPath[categoryPath.length - 2].name;
  }

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
            if (currentLevel > 1)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _goToPreviousLevel,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPreviousLevelText(),
                        style: const TextStyle(fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildCategorySelection(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: selectedCategory != null
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Catégorie sélectionnée :',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedCategory!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MatchMarketSwipePage(
                            category: selectedCategory!,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Commencer'),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildCategorySelection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('level', isEqualTo: currentLevel)
          .where(
            'parentId',
            isEqualTo: currentLevel == 1 ? null : categoryPath.last.id,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();

        if (categories.isEmpty) {
          return const Center(
            child: Text(
              'Aucune sous-catégorie disponible',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: categories.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              title: Text(
                category.name,
                style: TextStyle(
                  fontWeight: selectedCategory?.id == category.id
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              selected: selectedCategory?.id == category.id,
              selectedTileColor:
                  Theme.of(context).primaryColor.withOpacity(0.1),
              onTap: () => _goToNextLevel(category),
            );
          },
        );
      },
    );
  }
}
