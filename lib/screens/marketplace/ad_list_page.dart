import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/marketplace/ad_card.dart';
import 'package:happy/screens/marketplace/ad_detail_page.dart';
import 'package:happy/screens/marketplace/ad_type_selection_page.dart';
import 'package:happy/screens/marketplace/my_ad_page.dart';

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
      appBar: AppBar(
        title: const Text('Marketplace', style: TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickActions(),
          _buildFilterChips(),
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              padding: const EdgeInsets.all(10),
              itemCount: _ads.length + 1,
              itemBuilder: (context, index) {
                if (index >= _ads.length) {
                  return _buildLoader();
                }
                return AdCard(
                  ad: _ads[index],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdDetailPage(ad: _ads[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.add, 'Créer', () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdTypeSelectionScreen()));
          }),
          _buildActionButton(Icons.list, 'Mes annonces', () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const MyAdsPage()));
          }),
          _buildActionButton(Icons.bookmark, 'Sauvegardées', () {
            // Naviguer vers la page des annonces sauvegardées
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
        foregroundColor: Colors.black87,
        backgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Tous', 'Articles', 'Véhicules', 'Immobilier', 'Troc'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: filters
            .map((filter) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _selectedFilter == filter,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = selected ? filter : 'Tous';
                        _resetAndReloadAds();
                      });
                    },
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        alignment: Alignment.center,
        child: _isLoading
            ? const CircularProgressIndicator()
            : _hasMore
                ? ElevatedButton(
                    onPressed: _loadMoreAds,
                    child: const Text('Charger plus'),
                  )
                : const Text('Fin des résultats'),
      ),
    );
  }

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
