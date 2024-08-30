import 'package:flutter/material.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Vous pouvez ajouter une action supplémentaire ici si nécessaire
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText:
                      "Rechercher un utilisateur, un post ou une entreprise...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                  ),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
}
