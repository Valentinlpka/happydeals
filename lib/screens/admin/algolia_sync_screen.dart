import 'package:flutter/material.dart';
import 'package:happy/services/algolia_sync_service.dart';

class AlgoliaSyncScreen extends StatefulWidget {
  const AlgoliaSyncScreen({super.key});

  @override
  _AlgoliaSyncScreenState createState() => _AlgoliaSyncScreenState();
}

class _AlgoliaSyncScreenState extends State<AlgoliaSyncScreen> {
  final AlgoliaSyncService _syncService = AlgoliaSyncService();
  bool _isSyncing = false;
  String _statusMessage = '';
  double _progress = 0.0;
  final int _totalCollections = 4; // Nombre total de collections à synchroniser
  int _completedCollections = 0;

  Future<void> _syncCollection(String collection, String indexName) async {
    setState(() {
      _isSyncing = true;
      _statusMessage = 'Synchronisation de $collection...';
    });

    try {
      final success = await _syncService.syncCollection(
        collectionPath: collection,
        indexName: indexName,
      );

      setState(() {
        _completedCollections++;
        _progress = _completedCollections / _totalCollections;

        if (success) {
          _statusMessage =
              'Synchronisation de $collection terminée avec succès!';
        } else {
          _statusMessage = 'Erreur lors de la synchronisation de $collection';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur: $e';
      });
    }
  }

  Future<void> _syncAllCollections() async {
    setState(() {
      _isSyncing = true;
      _statusMessage = 'Démarrage de la synchronisation...';
      _progress = 0.0;
      _completedCollections = 0;
    });

    try {
      // Synchroniser les utilisateurs
      await _syncCollection('users', 'users');

      // Synchroniser les entreprises
      await _syncCollection('companys', 'companys');

      // Synchroniser les associations
      await _syncCollection('associations', 'associations');

      // Synchroniser les posts
      await _syncCollection('posts', 'posts');

      setState(() {
        _statusMessage = 'Synchronisation terminée avec succès!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur lors de la synchronisation: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _configureIndexes() async {
    setState(() {
      _isSyncing = true;
      _statusMessage = 'Configuration des index...';
    });

    try {
      // Configuration de base pour tous les index
      final Map<String, dynamic> baseSettings = {
        'searchableAttributes': ['*'],
        'attributesForFaceting': ['type', 'category'],
        'ranking': [
          'typo',
          'geo',
          'words',
          'filters',
          'proximity',
          'attribute',
          'exact',
          'custom'
        ],
      };

      // Configurer l'index users
      await _syncService.configureIndex(
        indexName: 'users',
        settings: {
          ...baseSettings,
          'searchableAttributes': [
            'firstName',
            'lastName',
            'email',
            'searchName',
          ],
        },
      );

      // Configurer l'index companys
      await _syncService.configureIndex(
        indexName: 'companys',
        settings: {
          ...baseSettings,
          'searchableAttributes': [
            'name',
            'description',
            'categorie',
            'searchText',
          ],
        },
      );

      // Configurer l'index associations
      await _syncService.configureIndex(
        indexName: 'associations',
        settings: {
          ...baseSettings,
          'searchableAttributes': [
            'name',
            'description',
            'category',
            'searchText',
          ],
        },
      );

      // Configurer l'index posts
      await _syncService.configureIndex(
        indexName: 'posts',
        settings: {
          ...baseSettings,
          'searchableAttributes': [
            'title',
            'description',
            'content',
            'searchText',
          ],
          'attributesForFaceting': ['type', 'companyId'],
        },
      );

      setState(() {
        _statusMessage = 'Configuration des index terminée avec succès!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Erreur lors de la configuration des index: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation Algolia'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Synchroniser les données avec Algolia',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Bouton pour synchroniser toutes les collections
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncAllCollections,
              icon: const Icon(Icons.sync),
              label: const Text('Synchroniser toutes les collections'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Synchronisation individuelle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Boutons pour synchroniser chaque collection individuellement
            _buildSyncButton('Utilisateurs', 'users'),
            _buildSyncButton('Entreprises', 'companys'),
            _buildSyncButton('Associations', 'associations'),
            _buildSyncButton('Publications', 'posts'),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Bouton pour configurer les index
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _configureIndexes,
              icon: const Icon(Icons.settings),
              label: const Text('Configurer les index'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            const SizedBox(height: 20),

            // Barre de progression
            if (_isSyncing) ...[
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 10),
            ],

            // Message de statut
            Text(
              _statusMessage,
              style: TextStyle(
                color: _statusMessage.contains('Erreur')
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncButton(String label, String collection) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        onPressed:
            _isSyncing ? null : () => _syncCollection(collection, collection),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 40),
        ),
        child: Text('Synchroniser $label'),
      ),
    );
  }
}
