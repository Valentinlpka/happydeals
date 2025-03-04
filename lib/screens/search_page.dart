import 'package:flutter/material.dart';
import 'package:happy/screens/marketplace/ad_list_page.dart';
import 'package:happy/screens/post_type_page/associations_page.dart';
import 'package:happy/screens/post_type_page/code_promo_page.dart';
import 'package:happy/screens/post_type_page/companys_page.dart';
import 'package:happy/screens/post_type_page/deal_express_page.dart';
import 'package:happy/screens/post_type_page/jeux_concours_page.dart';
import 'package:happy/screens/post_type_page/job_offer_page.dart';
import 'package:happy/screens/post_type_page/parrainage.dart';
import 'package:happy/screens/service_list_page.dart';
import 'package:happy/screens/shop/products_page.dart';
import 'package:happy/widgets/custom_app_bar.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBar(
        title: 'Rechercher',
        align: Alignment.center,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _buildSearchBar(),
          if (_searchTerm.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildFilters(),
            const SizedBox(height: 20),
            _buildSearchResults(),
          ] else ...[
            const SizedBox(height: 32),
            _buildDiscoverSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip("Tous"),
          _buildFilterChip("Utilisateurs"),
          _buildFilterChip("Posts"),
          _buildFilterChip("Entreprises"),
          _buildFilterChip("Associations"),
        ],
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
            gradient: isSelected
                ? LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
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

  Widget _buildSearchResults() {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 300,
      child: SearchResults(
        searchTerm: _searchTerm,
        filter: _selectedFilter,
      ),
    );
  }

  Widget _buildDiscoverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _getCategories().map((category) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 16),
              child: Text(
                category.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: category.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = category.items[index];
                return _buildDiscoverCard(item);
              },
            ),
            const SizedBox(height: 32),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDiscoverCard(DiscoverItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: item.gradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Category> _getCategories() {
    return [
      Category(
        title: 'Achats',
        items: [
          DiscoverItem(
            title: 'Produits',
            icon: Icons.local_offer,
            gradient: const LinearGradient(
              colors: [Color(0xFF6A1B9A), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductsPage()),
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
        ],
      ),
      Category(
        title: 'Bons plans',
        items: [
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
        ],
      ),
      Category(
        title: 'Découvrir',
        items: [
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
            title: 'Associations',
            icon: Icons.volunteer_activism,
            gradient: const LinearGradient(
              colors: [Color(0xFF8E24AA), Color(0xFFAB47BC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AssociationsPage()),
            ),
          ),
        ],
      ),
      Category(
        title: 'Opportunités',
        items: [
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
        ],
      ),
    ];
  }
}

class Category {
  final String title;
  final List<DiscoverItem> items;

  Category({
    required this.title,
    required this.items,
  });
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
