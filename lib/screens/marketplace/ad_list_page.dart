import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/marketplace/ad_card.dart';
import 'package:happy/screens/marketplace/ad_detail_page.dart';
import 'package:happy/screens/marketplace/ad_type_selection_page.dart';
import 'package:happy/screens/marketplace/my_ad_page.dart';
import 'package:happy/screens/marketplace/saved_ads_page.dart';

class AdListPage extends StatefulWidget {
  const AdListPage({super.key});

  @override
  _AdListPageState createState() => _AdListPageState();
}

class _AdListPageState extends State<AdListPage> {
  final ScrollController _scrollController = ScrollController();
  final int _limit = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  final List<Ad> _ads = [];
  String _selectedFilter = 'Tous';

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
                fontSize: 17,
                fontWeight: FontWeight.w600)),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterOptions,
        ),
      ],
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
    final filters = ['Tous', 'Articles', 'Véhicules', 'Troc'];
    final icons = {
      'Tous': Icons.all_inclusive,
      'Articles': Icons.shopping_bag,
      'Véhicules': Icons.directions_car,
      'Troc': Icons.swap_horiz,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                icon: Icon(
                  icons[filter], // Utiliser l'icône correspondante
                  color: isSelected ? Colors.white : Colors.black87,
                  size: 20,
                ),
                label: Text(filter),
                onPressed: () {
                  setState(() {
                    _selectedFilter = filter;
                    _resetAndReloadAds();
                  });
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: isSelected ? Colors.white : Colors.black87,
                  backgroundColor: isSelected ? Colors.blue : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: isSelected ? 4 : 1,
                ),
              ),
            ),
          );
        }).toList(),
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

    if (_selectedFilter != 'Tous') {
      String adType;
      switch (_selectedFilter.toLowerCase()) {
        case 'articles':
          adType = 'article';
          break;
        case 'véhicules':
          adType = 'vehicle';
          break;
        case 'troc':
          adType = 'exchange';
          break;
        default:
          adType = _selectedFilter.toLowerCase();
      }
      query = query.where('adType', isEqualTo: adType);
    }
    query = query.limit(_limit);
    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

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
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filtres avancés',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              // Ajoutez ici des options de filtrage plus avancées
              // Par exemple, des sliders pour la fourchette de prix, des checkboxes pour les catégories, etc.
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleSaveAd(Ad ad) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Vous devez être connecté pour sauvegarder une annonce')),
      );
      return;
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        List<String> savedAds =
            List<String>.from(userDoc.data()?['savedAds'] ?? []);

        if (savedAds.contains(ad.id)) {
          savedAds.remove(ad.id);
        } else {
          savedAds.add(ad.id);
        }

        transaction.update(userRef, {'savedAds': savedAds});
      });

      setState(() {
        ad.isSaved = !ad.isSaved;
      });
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
