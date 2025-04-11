import 'package:flutter/material.dart';
import 'package:happy/services/algolia_service.dart';

class SearchProvider extends ChangeNotifier {
  final AlgoliaService _algoliaService = AlgoliaService();

  Map<String, List<Map<String, dynamic>>> _searchResults = {};
  bool _isLoading = false;
  String _lastQuery = '';
  String _currentFilter = 'Tous';

  // Cache pour les résultats de recherche
  final Map<String, Map<String, List<Map<String, dynamic>>>> _searchCache = {};

  Map<String, List<Map<String, dynamic>>> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get lastQuery => _lastQuery;
  String get currentFilter => _currentFilter;

  List<Map<String, dynamic>> getResultsByType(String type) {
    return _searchResults[type] ?? [];
  }

  void setFilter(String filter) {
    if (_currentFilter == filter) return;

    _currentFilter = filter;
    if (_lastQuery.isNotEmpty) {
      // Vérifier si les résultats sont en cache pour ce filtre
      final cacheKey = '${_lastQuery}_$filter';
      if (_searchCache.containsKey(cacheKey)) {
        _searchResults = _searchCache[cacheKey]!;
        notifyListeners();
      } else {
        search(_lastQuery);
      }
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      _searchResults = {};
      _lastQuery = '';
      notifyListeners();
      return;
    }

    // Vérifier si les résultats sont en cache
    final cacheKey = '${query}_$_currentFilter';
    if (_searchCache.containsKey(cacheKey)) {
      _searchResults = _searchCache[cacheKey]!;
      _lastQuery = query;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _lastQuery = query;
    notifyListeners();

    try {
      Map<String, List<Map<String, dynamic>>> results = {};

      if (_currentFilter == "Tous") {
        // Recherche dans tous les index
        // Recherche d'utilisateurs
        results['users'] = await _algoliaService.search(
          query,
          indexName: 'users',
          hitsPerPage: 10,
        );

        // Recherche d'entreprises (tout ce qui n'est pas une association)
        results['companys'] = await _algoliaService.searchCompanies(
          query,
          hitsPerPage: 10,
        );

        // Recherche d'associations
        results['associations'] = await _algoliaService.searchAssociations(
          query,
          hitsPerPage: 10,
        );

        // Recherche de posts
        results['posts'] = await _algoliaService.search(
          query,
          indexName: 'posts',
          hitsPerPage: 10,
        );
      } else {
        // Recherche dans un index spécifique
        switch (_currentFilter) {
          case "Utilisateurs":
            final userResults = await _algoliaService.search(
              query,
              indexName: 'users',
              hitsPerPage: 20,
            );
            results = {'users': userResults};
            break;
          case "Entreprises":
            // Utiliser la nouvelle méthode pour les entreprises
            final companyResults = await _algoliaService.searchCompanies(
              query,
              hitsPerPage: 20,
            );
            results = {'companys': companyResults};
            break;
          case "Associations":
            final associationResults = await _algoliaService.searchCompanys(
              query,
              type: 'association',
              hitsPerPage: 20,
            );
            results = {'associations': associationResults};
            break;
          case "Posts":
            final postResults = await _algoliaService.search(
              query,
              indexName: 'posts',
              hitsPerPage: 20,
            );
            results = {'posts': postResults};
            break;
          default:
            results = {};
        }
      }

      // Mettre en cache les résultats
      _searchCache[cacheKey] = results;
      _searchResults = results;
    } catch (e) {
      debugPrint('Erreur lors de la recherche: $e');
      _searchResults = {};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    _searchResults = {};
    _lastQuery = '';
    notifyListeners();
  }
}
