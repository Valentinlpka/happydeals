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
                  hintText: "Rechercher un post ou une entreprise...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(5)),
                  ),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: SearchResults(searchTerm: _searchTerm),
            ),
          ],
        ),
      ),
    );
  }
}
