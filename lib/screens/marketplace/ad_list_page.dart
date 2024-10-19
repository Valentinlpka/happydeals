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
      body: CustomScrollView(
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
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _ads.length) {
                    return _buildLoader();
                  }
                  return _buildAdCard(_ads[index]);
                },
                childCount: _ads.length + 1,
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

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.grey[50],
      floating: false,
      pinned: false,
      flexibleSpace: const FlexibleSpaceBar(
        title: Text('Marketplace', style: TextStyle(color: Colors.black)),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.list, 'Mes annonces', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const MyAdsPage()));
          }),
          _buildActionButton(Icons.bookmark, 'Sauvegardées', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const SavedAdsPage()));
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue[600],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Tous', 'Articles', 'Véhicules', 'Troc'];
    return Padding(
      padding: const EdgeInsets.only(left: 20.0),
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(filters[index]),
                selected: _selectedFilter == filters[index],
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = selected ? filters[index] : 'Tous';
                    _resetAndReloadAds();
                  });
                },
                backgroundColor: Colors.white,
                selectedColor: Colors.blue[100],
                checkmarkColor: Colors.blue[700],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdCard(Ad ad) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: AdCard(
        ad: ad,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdDetailPage(ad: ad)),
        ),
        onSaveTap: () => _toggleSaveAd(ad),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: _isLoading
          ? const CircularProgressIndicator()
          : _hasMore
              ? ElevatedButton(
                  onPressed: _loadMoreAds,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue[600],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Charger plus'),
                )
              : const Text('Fin des résultats',
                  style: TextStyle(color: Colors.grey)),
    );
  }

  // Les autres méthodes (_onScroll, _loadMoreAds, _resetAndReloadAds, _showFilterOptions, _toggleSaveAd)
  // restent inchangées.

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
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
