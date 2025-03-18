import 'dart:convert';

import 'package:http/http.dart' as http;

class AlgoliaService {
  // Remplacez ces valeurs par vos propres clés Algolia
  static const String applicationId = 'AM8X4MK2SC';
  static const String searchApiKey = '4ec567474ac622c75ad16dfba5056ec0';
  static const String apiEndpoint =
      'https://$applicationId-dsn.algolia.net/1/indexes';

  // Recherche dans un seul index
  Future<List<Map<String, dynamic>>> search(
    String query, {
    required String indexName,
    String? filters,
    int hitsPerPage = 20,
  }) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('$apiEndpoint/$indexName/query');

    final Map<String, dynamic> requestBody = {
      'query': query,
      'hitsPerPage': hitsPerPage,
    };

    if (filters != null && filters.isNotEmpty) {
      requestBody['filters'] = filters;
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'X-Algolia-API-Key': searchApiKey,
          'X-Algolia-Application-Id': applicationId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['hits'] ?? []);
      } else {
        print('Erreur Algolia: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erreur lors de la recherche Algolia: $e');
      return [];
    }
  }

  // Recherche multi-index pour chercher dans plusieurs collections à la fois
  Future<Map<String, List<Map<String, dynamic>>>> searchMultiIndex(
    String query, {
    List<String> indexNames = const [
      'users',
      'companys',
      'associations',
      'posts'
    ],
    int hitsPerPage = 10,
  }) async {
    if (query.isEmpty) return {};

    Map<String, List<Map<String, dynamic>>> results = {};

    for (String indexName in indexNames) {
      try {
        final hits = await search(
          query,
          indexName: indexName,
          hitsPerPage: hitsPerPage,
        );
        results[indexName] = hits;
      } catch (e) {
        print('Erreur lors de la recherche dans l\'index $indexName: $e');
        results[indexName] = [];
      }
    }

    return results;
  }

  // Recherche spécifique pour les entreprises ou associations
  Future<List<Map<String, dynamic>>> searchCompanys(
    String query, {
    String? type,
    String? category,
    int hitsPerPage = 20,
  }) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('$apiEndpoint/companys/query');

    final Map<String, dynamic> requestBody = {
      'query': query,
      'hitsPerPage': hitsPerPage,
    };

    // Ajouter des filtres si nécessaire
    List<String> filters = [];

    if (type != null) {
      filters.add('type:$type');
    }

    if (category != null) {
      filters.add('categorie:$category');
    }

    if (filters.isNotEmpty) {
      requestBody['filters'] = filters.join(' AND ');
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'X-Algolia-API-Key': searchApiKey,
          'X-Algolia-Application-Id': applicationId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['hits'] ?? []);
      } else {
        print('Erreur Algolia: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erreur lors de la recherche Algolia: $e');
      return [];
    }
  }

  // Recherche spécifique pour les entreprises (tout ce qui n'est pas une association)
  Future<List<Map<String, dynamic>>> searchCompanies(
    String query, {
    String? category,
    int hitsPerPage = 20,
  }) async {
    if (query.isEmpty) return [];

    final url = Uri.parse('$apiEndpoint/companys/query');

    final Map<String, dynamic> requestBody = {
      'query': query,
      'hitsPerPage': hitsPerPage,
      // Filtre pour exclure les associations
      'filters': 'NOT type:association',
    };

    // Ajouter des filtres supplémentaires si nécessaire
    if (category != null && category.isNotEmpty) {
      requestBody['filters'] = '(NOT type:association) AND categorie:$category';
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'X-Algolia-API-Key': searchApiKey,
          'X-Algolia-Application-Id': applicationId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['hits'] ?? []);
      } else {
        print('Erreur Algolia: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erreur lors de la recherche Algolia: $e');
      return [];
    }
  }

  // Recherche spécifique pour les associations
  Future<List<Map<String, dynamic>>> searchAssociations(
    String query, {
    String? category,
    int hitsPerPage = 20,
  }) async {
    // Utiliser la méthode existante avec le filtre type:association
    return searchCompanys(
      query,
      type: 'association',
      category: category,
      hitsPerPage: hitsPerPage,
    );
  }

  Future<List<Map<String, dynamic>>> searchProducts(
    String query, {
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    bool? isActive = true,
    int hitsPerPage = 20,
  }) async {
    try {
      // Construire les filtres
      List<String> filters = [];

      if (isActive != null) {
        filters.add('isActive:$isActive');
      }

      if (categoryId != null && categoryId.isNotEmpty) {
        filters.add('categoryPath:$categoryId');
      }

      if (minPrice != null) {
        filters.add('price >= $minPrice');
      }

      if (maxPrice != null) {
        filters.add('price <= $maxPrice');
      }

      // Construire la requête
      final Map<String, dynamic> requestBody = {
        'query': query,
        'hitsPerPage': hitsPerPage,
      };

      if (filters.isNotEmpty) {
        requestBody['filters'] = filters.join(' AND ');
      }

      // Exécuter la recherche
      final response = await http.post(
        Uri.parse('$apiEndpoint/products/query'),
        headers: {
          'X-Algolia-API-Key': searchApiKey,
          'X-Algolia-Application-Id': applicationId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Traiter les résultats
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['hits'] ?? []);
      } else {
        print('Erreur Algolia: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erreur lors de la recherche de produits: $e');
      return [];
    }
  }
}
