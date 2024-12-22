import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CategoryImportScreen extends StatefulWidget {
  const CategoryImportScreen({super.key});

  @override
  State<CategoryImportScreen> createState() => _CategoryImportScreenState();
}

class _CategoryImportScreenState extends State<CategoryImportScreen> {
  bool _isLoading = false;
  String _status = '';

  // Liste des fichiers JSON dans l'ordre d'importation souhaité
  final List<String> rootJsonFiles = [
    'assets/json1.json', // mode_et_accessoires
    'assets/json5.json', // beaute_sante
    'assets/json6.json', // sport_loisirs
    'assets/json10.json', // alimentation_entretien
    'assets/json17.json', // high_tech
    'assets/json18.json', // jouets_enfants_bebes
    'assets/json19.json', // artisanat_france
  ];

  final List<String> otherJsonFiles = [
    'assets/json2.json',
    'assets/json3.json',
    'assets/json4.json',
    'assets/json7.json',
    'assets/json8.json',
    'assets/json9.json',
    'assets/json11.json',
    'assets/json12.json',
    'assets/json13.json',
    'assets/json14.json',
    'assets/json15.json',
    'assets/json16.json',
  ];
  Future<void> uploadCategoriesToFirestore(String fileName) async {
    try {
      // Lire le fichier JSON
      final jsonString = await rootBundle.loadString(fileName);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      final firestore = FirebaseFirestore.instance;
      var batch = firestore.batch();
      var batchCount = 0;
      final categories = jsonData['categories'] as Map<String, dynamic>;

      // Convertir en liste pour pouvoir parcourir avec un index
      final entries = categories.entries.toList();

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        final key = entry.key;
        final value = entry.value;

        final docRef = firestore.collection('categories').doc(key);
        batch.set(
          docRef,
          {
            'name': value['name'],
            'level': value['level'],
            'parentId': value['parentId'],
            'hasAttributes': value['hasAttributes'] ?? false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        batchCount++;

        // Si on atteint 500 ou si c'est la dernière entrée
        if (batchCount >= 500 || i == entries.length - 1) {
          await batch.commit(); // Attendre que le commit soit terminé
          batch = firestore.batch(); // Créer un nouveau batch
          batchCount = 0; // Réinitialiser le compteur
        }
      }

      setState(() {
        _status = '$_status\nImportation réussie: $fileName';
      });
    } catch (e) {
      setState(() {
        _status = '$_status\nErreur pour $fileName: $e';
      });
      rethrow;
    }
  }

  Future<void> importAllCategories() async {
    setState(() {
      _isLoading = true;
      _status = 'Début de l\'importation...';
    });

    try {
      // D'abord importer les catégories racines
      for (final fileName in rootJsonFiles) {
        setState(() {
          _status = '$_status\nTraitement de $fileName...';
        });
        await uploadCategoriesToFirestore(fileName);
      }

      // Ensuite importer les autres catégories
      for (final fileName in otherJsonFiles) {
        setState(() {
          _status = '$_status\nTraitement de $fileName...';
        });
        await uploadCategoriesToFirestore(fileName);
      }

      setState(() {
        _status = '$_status\n\nImportation terminée avec succès!';
      });
    } catch (e) {
      setState(() {
        _status = '$_status\nErreur globale: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import des catégories'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: importAllCategories,
                child: const Text('Upload Categories'),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
