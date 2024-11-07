import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/category.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/screens/marketplace/ad_card.dart';
import 'package:happy/screens/marketplace/ad_detail_page.dart';
import 'package:happy/screens/marketplace/ad_type_selection_page.dart';
import 'package:happy/screens/marketplace/my_ad_page.dart';
import 'package:happy/screens/marketplace/saved_ads_page.dart';
import 'package:provider/provider.dart';

class AdListPage extends StatefulWidget {
  const AdListPage({super.key});

  @override
  _AdListPageState createState() => _AdListPageState();
}

class ActiveFilter {
  final String type;
  final String value;
  final String displayText;

  ActiveFilter({
    required this.type,
    required this.value,
    required this.displayText,
  });
}

class _AdListPageState extends State<AdListPage> {
  final List<ActiveFilter> _activeFiltersList = [];

  // ... autres variables existantes ...

  // Variables pour les filtres
  String? selectedType;
  RangeValues priceRange = const RangeValues(0, 1000);
  String? selectedCondition;
  RangeValues yearRange = RangeValues(
    DateTime.now().year - 20.0,
    DateTime.now().year.toDouble(),
  );
  String? selectedBrand;
  String? selectedCategory;
  String? selectedSubCategory;
  double? minPrice;
  double? maxPrice;

  final ScrollController _scrollController = ScrollController();
  final int _limit = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  final List<Ad> _ads = [];

  @override
  void initState() {
    super.initState();
    _loadMoreAds();
    _scrollController.addListener(_onScroll);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        // Ajout d'un Stack pour superposer le loader
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(child: _buildQuickActions()),
              SliverToBoxAdapter(child: _buildFilterChips()),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _ads.length) {
                        return null; // Ne plus afficher de loader ici
                      }
                      return _buildAdCard(_ads[index]);
                    },
                    childCount: _ads
                        .length, // Modifier le childCount pour n'inclure que les annonces
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading) // Afficher le loader en bas au centre
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const AdTypeSelectionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Créer une annonce'),
      ),
    );
  }

// Le widget _buildLoader n'est plus nécessaire, vous pouvez le supprimer
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: Colors.grey[300],
          height: 1.0,
        ),
      ),
      backgroundColor: Colors.grey[50],
      floating: false,
      pinned: false,
      flexibleSpace: const FlexibleSpaceBar(
        title: Text('Marketplace',
            style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _buildActionButton('Mes annonces', Icons.list, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyAdsPage()),
            );
          }),
          const SizedBox(width: 8), // Espacement entre les boutons
          _buildActionButton('Sauvegardées', Icons.bookmark, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SavedAdsPage()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, VoidCallback onPressed) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton.icon(
        icon: Icon(
          icon,
          color: Colors.black87,
          size: 20,
        ),
        label: Text(title),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black87,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 1,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // Bouton Filtrer
          if (_activeFiltersList.isEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Filtrer'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black87,
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _showFilterOptions,
            ),

          // Filtres actifs
          if (_activeFiltersList.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: _activeFiltersList.map((filter) {
                return Chip(
                  label: Text(filter.displayText),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () {
                    setState(() {
                      _activeFiltersList.remove(filter);
                      // Réinitialiser le filtre correspondant
                      switch (filter.type) {
                        case 'type':
                          selectedType = null;
                          break;
                        case 'condition':
                          selectedCondition = null;
                          break;
                        case 'price':
                          priceRange = const RangeValues(
                              0, 1000); // Réinitialiser la fourchette de prix
                          break;
                        case 'category':
                          selectedCategory = null;
                          selectedSubCategory = null;
                          break;
                        case 'brand':
                          selectedBrand = null;
                          break;
                      }
                      _applyFilters(); // Réappliquer les filtres
                    });
                  },
                  backgroundColor: Colors.blue[100],
                  deleteIconColor: Colors.blue[800],
                  labelStyle: TextStyle(color: Colors.blue[800]),
                );
              }).toList(),
            ),
            const SizedBox(width: 8),
            // Bouton pour ajouter plus de filtres
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showFilterOptions,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdCard(Ad ad) {
    return AdCard(
      ad: ad,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AdDetailPage(ad: ad)),
      ),
      onSaveTap: () => _toggleSaveAd(ad),
    );
  }

  Widget _buildLoader() {
    if (!_hasMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child:
              Text('Fin des résultats', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _onScroll() {
    // Charger plus tôt, quand on atteint 80% du scroll
    if (!_isLoading &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreAds();
    }
  }

  void _resetAndReloadAds() {
    setState(() {
      _ads.clear();
      _lastDocument = null;
      _hasMore = true;
    });
    _loadMoreAds();
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtres',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Type de l'annonce
                      Text(
                        'Type d\'annonce',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildTypeChip(
                            'Articles',
                            Icons.shopping_bag,
                            selectedType == 'article',
                            () => setState(() => selectedType = 'article'),
                          ),
                          const SizedBox(width: 8),
                          _buildTypeChip(
                            'Véhicules',
                            Icons.directions_car,
                            selectedType == 'vehicle',
                            () => setState(() => selectedType = 'vehicle'),
                          ),
                          const SizedBox(width: 8),
                          _buildTypeChip(
                            'Troc',
                            Icons.swap_horiz,
                            selectedType == 'exchange',
                            () => setState(() => selectedType = 'exchange'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Filtres spécifiques selon le type
                      if (selectedType != null) ...[
                        _buildSpecificFilters(selectedType!, setState),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  selectedType = null;
                                  priceRange = const RangeValues(0, 1000);
                                  selectedCondition = null;
                                  yearRange = RangeValues(
                                    DateTime.now().year - 20.0,
                                    DateTime.now().year.toDouble(),
                                  );
                                  selectedBrand = null;
                                  selectedCategory = null;
                                  selectedSubCategory = null;
                                });
                              },
                              child: const Text('Réinitialiser'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // Appliquer les filtres
                                Navigator.pop(context);
                                _applyFilters();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Appliquer'),
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
      },
    );
  }

// Pour gérer les variables des filtres au niveau de la classe
  Map<String, dynamic> _activeFilters = {};
  String _getDisplayTextForType(String type) {
    switch (type) {
      case 'article':
        return 'Articles';
      case 'vehicle':
        return 'Véhicules';
      case 'exchange':
        return 'Troc';
      default:
        return type;
    }
  }

  void _applyFilters() {
    setState(() {
      _ads.clear();
      _lastDocument = null;
      _hasMore = true;
      _activeFiltersList.clear(); // Réinitialiser la liste des filtres actifs

      // Ajouter les filtres actifs à la liste
      if (selectedType != null) {
        _activeFiltersList.add(ActiveFilter(
          type: 'type',
          value: selectedType!,
          displayText: _getDisplayTextForType(selectedType!),
        ));
      }

      if (selectedCondition != null) {
        _activeFiltersList.add(ActiveFilter(
          type: 'condition',
          value: selectedCondition!,
          displayText: selectedCondition!,
        ));
      }

      if (priceRange.start > 0 || priceRange.end < 1000) {
        _activeFiltersList.add(ActiveFilter(
          type: 'price',
          value: '${priceRange.start}-${priceRange.end}',
          displayText:
              '${priceRange.start.round()}€ - ${priceRange.end.round()}€',
        ));
      }

      // Ajoutez d'autres filtres selon vos besoins

      _activeFilters = {
        if (selectedType != null) 'type': selectedType,
        if (priceRange.start > 0) 'minPrice': priceRange.start,
        if (priceRange.end < 1000) 'maxPrice': priceRange.end,
        if (selectedCondition != null) 'condition': selectedCondition,
        if (selectedBrand != null) 'brand': selectedBrand,
        if (selectedCategory != null) 'category': selectedCategory,
        if (selectedSubCategory != null) 'subCategory': selectedSubCategory,
      };
    });
    _loadMoreAds();
  }

// Mettre à jour _loadMoreAds pour prendre en compte les filtres
  void _loadMoreAds() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
    });

    Query query = FirebaseFirestore.instance
        .collection('ads')
        .where('status', isNotEqualTo: 'sold')
        .orderBy('status')
        .orderBy('createdAt', descending: true);

    // Appliquer les filtres
    if (_activeFilters.isNotEmpty) {
      if (_activeFilters['type'] != null) {
        query = query.where('adType', isEqualTo: _activeFilters['type']);
      }
      if (_activeFilters['category'] != null) {
        query = query.where('category', isEqualTo: _activeFilters['category']);
      }
      if (_activeFilters['condition'] != null) {
        query =
            query.where('condition', isEqualTo: _activeFilters['condition']);
      }
      if (_activeFilters['minPrice'] != null) {
        query = query.where('price',
            isGreaterThanOrEqualTo: _activeFilters['minPrice']);
      }
      if (_activeFilters['maxPrice'] != null) {
        query = query.where('price',
            isLessThanOrEqualTo: _activeFilters['maxPrice']);
      }
      if (_activeFilters['brand'] != null) {
        query = query.where('brand', isEqualTo: _activeFilters['brand']);
      }
    }

    query = query.limit(_limit);
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    try {
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;
      final newAds = await Future.wait(
          snapshot.docs.map((doc) => Ad.fromFirestore(doc)).toList());

      setState(() {
        _ads.addAll(newAds);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Erreur lors du chargement des annonces: $e');
    }
  }

  Widget _buildTypeChip(
      String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecificFilters(String type, StateSetter setState) {
    switch (type) {
      case 'article':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPriceRangeFilter(setState),
            const SizedBox(height: 20),
            _buildConditionFilter(setState),
            const SizedBox(height: 20),
            _buildCategoryFilter(setState),
          ],
        );
      case 'vehicle':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPriceRangeFilter(setState),
            const SizedBox(height: 20),
            _buildBrandFilter(setState),
            const SizedBox(height: 20),
            _buildYearFilter(setState),
          ],
        );
      case 'exchange':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryFilter(setState),
            const SizedBox(height: 20),
            _buildConditionFilter(setState),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPriceRangeFilter(StateSetter setBottomSheetState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fourchette de prix',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${priceRange.start.round()}€'),
                  Text('${priceRange.end.round()}€'),
                ],
              ),
              RangeSlider(
                values: priceRange,
                min: 0,
                max: 1000,
                divisions: 20,
                labels: RangeLabels(
                  '${priceRange.start.round()}€',
                  '${priceRange.end.round()}€',
                ),
                onChanged: (RangeValues values) {
                  setBottomSheetState(() {
                    priceRange = values;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConditionFilter(StateSetter setBottomSheetState) {
    final conditions = [
      'Neuf',
      'Très bon état',
      'Bon état',
      'État satisfaisant',
      'Pour pièces'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'État',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: conditions.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[300],
            ),
            itemBuilder: (context, index) {
              final condition = conditions[index];
              return RadioListTile<String>(
                title: Text(condition),
                value: condition,
                groupValue: selectedCondition,
                onChanged: (value) {
                  setBottomSheetState(() {
                    selectedCondition = value;
                  });
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catégorie',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                // Utiliser votre sélecteur de catégorie existant
                _showCategoryPicker();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      selectedSubCategory ?? 'Sélectionner une catégorie',
                      style: TextStyle(
                        color: selectedSubCategory != null
                            ? Colors.black
                            : Colors.grey[600],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCategoryPicker() {
    // Charger les catégories depuis votre JSON
    final categories = [
      Category.fromJson({
        "nom": "Véhicules",
        "sous-catégories": ["Voitures", "Motos", "Caravaning", "Nautisme"]
      }),
      Category.fromJson({
        "nom": "Équipements",
        "sous-catégories": [
          "Équipement auto",
          "Équipement moto",
          "Équipement vélo",
          "Équipements pour bureau",
          "Équipements pour restaurants",
          "Équipements pour hôtels",
          "Équipements médicaux"
        ]
      }),
      // ... autres catégories
    ];

    String? tempCategory;
    String? tempSubCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sélectionner une catégorie',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Row(
                      children: [
                        // Catégories principales
                        Expanded(
                          child: Container(
                            color: Colors.white,
                            child: ListView.builder(
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                final isSelected =
                                    category.name == tempCategory;
                                return Container(
                                  color: isSelected
                                      ? Colors.blue.withOpacity(0.1)
                                      : null,
                                  child: ListTile(
                                    title: Text(
                                      category.name,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.blue[600]
                                            : Colors.black,
                                        fontWeight:
                                            isSelected ? FontWeight.bold : null,
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        tempCategory = category.name;
                                        tempSubCategory = null;
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Sous-catégories
                        Expanded(
                          child: Container(
                            color: Colors.grey[50],
                            child: tempCategory == null
                                ? const Center(
                                    child: Text('Sélectionnez une catégorie'),
                                  )
                                : ListView.builder(
                                    itemCount: categories
                                        .firstWhere(
                                            (cat) => cat.name == tempCategory)
                                        .subCategories
                                        .length,
                                    itemBuilder: (context, index) {
                                      final subCategories = categories
                                          .firstWhere(
                                              (cat) => cat.name == tempCategory)
                                          .subCategories;
                                      final subCategory = subCategories[index];
                                      final isSelected =
                                          subCategory == tempSubCategory;

                                      return ListTile(
                                        title: Text(
                                          subCategory,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.blue[600]
                                                : Colors.black,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : null,
                                          ),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            tempSubCategory = subCategory;
                                          });
                                          // Mettre à jour les sélections et fermer
                                          this.setState(() {
                                            selectedCategory = tempCategory;
                                            selectedSubCategory =
                                                tempSubCategory;
                                          });
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
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

  Widget _buildBrandFilter(StateSetter setState) {
    List<String> brands = []; // À remplir selon le type de véhicule
    String? selectedBrand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Marque',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedBrand,
              isExpanded: true,
              hint: const Text('Sélectionner une marque'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              items: brands.map((brand) {
                return DropdownMenuItem(
                  value: brand,
                  child: Text(brand),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedBrand = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearFilter(StateSetter setState) {
    RangeValues? currentYearRange = RangeValues(
      DateTime.now().year - 20.0,
      DateTime.now().year.toDouble(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Année',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${currentYearRange.start.round()}'),
                  Text('${currentYearRange.end.round()}'),
                ],
              ),
              RangeSlider(
                values: currentYearRange,
                min: DateTime.now().year - 50.0,
                max: DateTime.now().year.toDouble(),
                divisions: 50,
                labels: RangeLabels(
                  '${currentYearRange.start.round()}',
                  '${currentYearRange.end.round()}',
                ),
                onChanged: (RangeValues values) {
                  setState(() {
                    currentYearRange = values;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleSaveAd(Ad ad) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Vous devez être connecté pour sauvegarder une annonce'),
        ),
      );
      return;
    }

    try {
      final savedAdsProvider =
          Provider.of<SavedAdsProvider>(context, listen: false);
      await savedAdsProvider.toggleSaveAd(user.uid, ad.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
