import 'package:flutter/material.dart';
import 'package:happy/screens/marketplace/ad_list_page.dart';
import 'package:happy/screens/post_type_page/code_promo_page.dart';
import 'package:happy/screens/post_type_page/companys_page.dart';
import 'package:happy/screens/post_type_page/deal_express_page.dart';
import 'package:happy/screens/post_type_page/happy_deals_page.dart';
import 'package:happy/screens/post_type_page/jeux_concours_page.dart';
import 'package:happy/screens/post_type_page/job_offer_page.dart';
import 'package:happy/screens/post_type_page/parrainage.dart';
import 'package:happy/screens/service_list_page.dart';
import 'package:happy/widgets/search_result.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";
  String _selectedFilter = "Tous";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text;
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            const SliverAppBar(
              title: Text('Rechercher',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),

            // Barre de recherche
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Rechercher...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                    ),
                  ),
                ),
              ),
            ),

            // Filtres de recherche si recherche active
            if (_searchTerm.isNotEmpty)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildFilterChip("Tous"),
                      _buildFilterChip("Utilisateurs"),
                      _buildFilterChip("Posts"),
                      _buildFilterChip("Entreprises"),
                    ],
                  ),
                ),
              ),

            // Résultats de recherche ou grille de découverte
            if (_searchTerm.isNotEmpty)
              SliverFillRemaining(
                child: SearchResults(
                  searchTerm: _searchTerm,
                  filter: _selectedFilter,
                ),
              )
            else ...[
              // Titre Découvrir
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 24, bottom: 16),
                  child: Text(
                    "Découvrir",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              // Grille de découverte
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 100,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final items = _getDiscoverItems(context);
                      return _buildDiscoverCard(items[index]);
                    },
                    childCount: _getDiscoverItems(context).length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4B88DA) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDiscoverGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildDiscoverItem('Annuaire', Icons.book, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const CompaniesPage()));
        }),
        _buildDiscoverItem('Offres d\'emploi', Icons.work, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const JobOffersPage()));
        }),
        _buildDiscoverItem('Happy Deals', Icons.local_offer, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const HappyDealsPage()));
        }),
        _buildDiscoverItem('Deals Express', Icons.flash_on, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const DealExpressPage()));
        }),
        _buildDiscoverItem('Jeux concours', Icons.emoji_events, () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const JeuxConcoursPage()));
        }),
        _buildDiscoverItem('Offres de parrainage', Icons.card_giftcard, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const ParraiangePage()));
        }),
        _buildDiscoverItem('Marketplace', Icons.store, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AdListPage()));
        }),
        _buildDiscoverItem('Services', Icons.store, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const ServiceListPage()));
        }),
        _buildDiscoverItem('Code promo', Icons.store, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const CodePromoPage()));
        }),
      ],
    );
  }

  List<DiscoverItem> _getDiscoverItems(BuildContext context) {
    return [
      DiscoverItem(
        title: 'Annuaire',
        icon: Icons.business_center,
        gradient: const LinearGradient(
          colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CompaniesPage()),
        ),
      ),
      DiscoverItem(
        title: 'Offres d\'emploi',
        icon: Icons.work_outline,
        gradient: const LinearGradient(
          colors: [Color(0xFF00796B), Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const JobOffersPage()),
        ),
      ),
      DiscoverItem(
        title: 'Happy Deals',
        icon: Icons.local_offer,
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HappyDealsPage()),
        ),
      ),
      DiscoverItem(
        title: 'Deals Express',
        icon: Icons.flash_on,
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DealExpressPage()),
        ),
      ),
      DiscoverItem(
        title: 'Jeux concours',
        icon: Icons.emoji_events,
        gradient: const LinearGradient(
          colors: [Color(0xFFC62828), Color(0xFFEF5350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const JeuxConcoursPage()),
        ),
      ),
      DiscoverItem(
        title: 'Offres de parrainage',
        icon: Icons.people_outline,
        gradient: const LinearGradient(
          colors: [Color(0xFF4527A0), Color(0xFF7E57C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ParraiangePage()),
        ),
      ),
      DiscoverItem(
        title: 'Marketplace',
        icon: Icons.storefront,
        gradient: const LinearGradient(
          colors: [Color(0xFF283593), Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdListPage()),
        ),
      ),
      DiscoverItem(
        title: 'Services',
        icon: Icons.miscellaneous_services,
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ServiceListPage()),
        ),
      ),
      DiscoverItem(
        title: 'Code promo',
        icon: Icons.confirmation_number,
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CodePromoPage()),
        ),
      ),
    ];
  }

  Widget _buildDiscoverCard(DiscoverItem item) {
    return Container(
      decoration: BoxDecoration(
        gradient: item.gradient,
        borderRadius: BorderRadius.circular(12), // Bordure légèrement réduite
        boxShadow: [
          BoxShadow(
            color: item.gradient.colors.first.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12), // Padding réduit
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: Colors.white,
                  size: 28, // Taille d'icône réduite
                ),
                const SizedBox(height: 8), // Espacement réduit
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13, // Taille de texte réduite
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverItem(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }
}

class DiscoverItem {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  DiscoverItem({
    required this.title,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}
