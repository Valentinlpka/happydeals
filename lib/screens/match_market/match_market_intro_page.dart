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
  Category? parentCategory;
  int currentLevel = 1;

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
                      onPressed: () {
                        setState(() {
                          currentLevel--;
                          if (currentLevel == 1) {
                            parentCategory = null;
                          } else {
                            selectedCategory = parentCategory;
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Retour au niveau précédent',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _buildCategorySelection(),
            ),
            if (selectedCategory != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Catégorie sélectionnée : ${selectedCategory!.name}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
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
                            child: const Text('Commencer avec cette catégorie'),
                          ),
                        ),
                        if (currentLevel < 4) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  currentLevel++;
                                  parentCategory = selectedCategory;
                                  selectedCategory = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                              ),
                              child: const Text('Voir les sous-catégories'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('categories')
          .where('level', isEqualTo: currentLevel)
          .where(
            'parentId',
            isEqualTo: currentLevel == 1 ? null : parentCategory?.id,
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedCategory?.id == category.id)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).primaryColor,
                    )
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
              selected: selectedCategory?.id == category.id,
              selectedTileColor:
                  Theme.of(context).primaryColor.withOpacity(0.1),
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
}
