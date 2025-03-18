import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AlgoliaSyncService {
  // Remplacez ces valeurs par vos propres clés Algolia
  static const String applicationId = 'VOTRE_APPLICATION_ID';
  static const String adminApiKey =
      'VOTRE_ADMIN_API_KEY'; // Clé Admin, pas la clé de recherche
  static const String apiEndpoint =
      'https://$applicationId-dsn.algolia.net/1/indexes';

  // Synchroniser un document avec Algolia
  Future<bool> syncDocument({
    required String indexName,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Ajouter l'ID comme objectID pour Algolia
      final objectData = {
        'objectID': documentId,
        ...data,
      };

      final url = Uri.parse('$apiEndpoint/$indexName/$documentId');

      final response = await http.put(
        url,
        headers: {
          'X-Algolia-API-Key': adminApiKey,
          'X-Algolia-Application-Id': applicationId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(objectData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Document synchronisé avec Algolia: $documentId');
        return true;
      } else {
        debugPrint('Erreur Algolia: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation avec Algolia: $e');
      return false;
    }
  }

  // Supprimer un document d'Algolia
  Future<bool> deleteDocument({
    required String indexName,
    required String documentId,
  }) async {
    try {
      final url = Uri.parse('$apiEndpoint/$indexName/$documentId');

      final response = await http.delete(
        url,
        headers: {
          'X-Algolia-API-Key': adminApiKey,
          'X-Algolia-Application-Id': applicationId,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('Document supprimé d\'Algolia: $documentId');
        return true;
      } else {
        debugPrint('Erreur Algolia: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Erreur lors de la suppression dans Algolia: $e');
      return false;
    }
  }

  // Synchroniser une collection entière
  Future<bool> syncCollection({
    required String collectionPath,
    required String indexName,
    int batchSize = 100,
  }) async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection(collectionPath).get();

      if (snapshot.docs.isEmpty) {
        debugPrint('Aucun document à synchroniser dans $collectionPath');
        return true;
      }

      // Préparer les données pour l'envoi par lots
      List<Map<String, dynamic>> objects = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        objects.add({
          'objectID': doc.id,
          ...data,
        });

        // Envoi par lots pour éviter de surcharger l'API
        if (objects.length >= batchSize) {
          final success = await _sendBatch(indexName, objects);
          if (!success) return false;
          objects.clear();
        }
      }

      // Envoi des objets restants
      if (objects.isNotEmpty) {
        final success = await _sendBatch(indexName, objects);
        if (!success) return false;
      }

      debugPrint('Synchronisation terminée pour $collectionPath');
      return true;
    } catch (e) {
      debugPrint('Erreur lors de la synchronisation de la collection: $e');
      return false;
    }
  }

  // Méthode privée pour envoyer un lot d'objets
  Future<bool> _sendBatch(
      String indexName, List<Map<String, dynamic>> objects) async {
    try {
      final url = Uri.parse('$apiEndpoint/$indexName/batch');

      final List<Map<String, dynamic>> requests = objects
          .map((obj) => {
                'action': 'updateObject',
                'body': obj,
              })
          .toList();

      final response = await http.post(
        url,
        headers: {
          'X-Algolia-API-Key': adminApiKey,
          'X-Algolia-Application-Id': applicationId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'requests': requests}),
      );

      if (response.statusCode == 200) {
        debugPrint('Lot de ${objects.length} objets synchronisé avec succès');
        return true;
      } else {
        debugPrint('Erreur Algolia: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi du lot: $e');
      return false;
    }
  }

  // Méthode pour configurer les paramètres d'un index
  Future<bool> configureIndex({
    required String indexName,
    required Map<String, dynamic> settings,
  }) async {
    try {
      final url = Uri.parse('$apiEndpoint/$indexName/settings');

      final response = await http.put(
        url,
        headers: {
          'X-Algolia-API-Key': adminApiKey,
          'X-Algolia-Application-Id': applicationId,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(settings),
      );

      if (response.statusCode == 200) {
        debugPrint('Index $indexName configuré avec succès');
        return true;
      } else {
        debugPrint('Erreur Algolia: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Erreur lors de la configuration de l\'index: $e');
      return false;
    }
  }
}
