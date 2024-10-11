import 'package:flutter/material.dart';
import 'package:happy/screens/post_type_page/companys_page.dart';
import 'package:happy/screens/post_type_page/deal_express_page.dart';
import 'package:happy/screens/post_type_page/happy_deals_page.dart';
import 'package:happy/screens/post_type_page/jeux_concours_page.dart';
import 'package:happy/screens/post_type_page/job_offer_page.dart';
import 'package:happy/screens/post_type_page/parrainage.dart';
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
      appBar: AppBar(
        title: const Text("Recherche"),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Rechercher...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          if (_searchTerm.isNotEmpty) ...[
            SingleChildScrollView(
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
            Expanded(
              child: SearchResults(
                searchTerm: _searchTerm,
                filter: _selectedFilter,
              ),
            ),
          ] else ...[
            Expanded(
              child: ListView(
                children: [
                  _buildSectionTitle("Découvrir"),
                  _buildDiscoverGrid(context),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: _selectedFilter == label,
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = selected ? label : "Tous";
          });
        },
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
      ],
    );
  }

  Widget _buildDiscoverItem(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
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
