import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/association.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/search_provider.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:provider/provider.dart';

class SearchResults extends StatefulWidget {
  final String searchTerm;
  final String filter;

  const SearchResults({
    super.key,
    required this.searchTerm,
    required this.filter,
  });

  @override
  State<SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<SearchResults> {
  // Cache pour stocker les widgets déjà construits
  final Map<String, Widget> _widgetCache = {};

  @override
  Widget build(BuildContext context) {
    if (widget.searchTerm.isEmpty) {
      return const Center(child: Text("Saisissez un terme pour rechercher"));
    }

    // Utiliser le provider pour la recherche
    final searchProvider = Provider.of<SearchProvider>(context);

    // Mettre à jour le filtre si nécessaire
    if (searchProvider.currentFilter != widget.filter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchProvider.setFilter(widget.filter);
      });
    }

    // Effectuer la recherche si le terme a changé
    if (searchProvider.lastQuery != widget.searchTerm &&
        widget.searchTerm.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchProvider.search(widget.searchTerm);
      });
    }

    if (searchProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Vérifier si nous avons des résultats
    bool hasResults = false;
    searchProvider.searchResults.forEach((key, value) {
      if (value.isNotEmpty) hasResults = true;
    });

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat trouvé pour "${widget.searchTerm}"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Construire les résultats
    return _buildResultsList(context, searchProvider);
  }

  Widget _buildResultsList(
      BuildContext context, SearchProvider searchProvider) {
    List<Widget> resultWidgets = [];

    if (widget.filter == "Tous") {
      // Afficher tous les types de résultats avec des en-têtes

      // Utilisateurs
      final userResults = searchProvider.getResultsByType('users');
      if (userResults.isNotEmpty) {
        resultWidgets.add(_buildSectionHeader('Utilisateurs'));
        resultWidgets.addAll(_buildUserResults(context, userResults));
      }

      // Entreprises
      final companyResults = searchProvider.getResultsByType('companys');
      if (companyResults.isNotEmpty) {
        resultWidgets.add(_buildSectionHeader('Entreprises'));
        resultWidgets.addAll(_buildCompanyResults(context, companyResults));
      }

      // Associations
      final associationResults =
          searchProvider.getResultsByType('associations');
      if (associationResults.isNotEmpty) {
        resultWidgets.add(_buildSectionHeader('Associations'));
        resultWidgets
            .addAll(_buildAssociationResults(context, associationResults));
      }

      // Posts
      final postResults = searchProvider.getResultsByType('posts');
      if (postResults.isNotEmpty) {
        resultWidgets.add(_buildSectionHeader('Publications'));
        resultWidgets.addAll(_buildPostResults(context, postResults));
      }
    } else {
      // Afficher uniquement le type sélectionné
      String indexName;
      switch (widget.filter) {
        case "Utilisateurs":
          indexName = 'users';
          resultWidgets.addAll(_buildUserResults(
              context, searchProvider.getResultsByType(indexName)));
          break;
        case "Entreprises":
          indexName = 'companys';
          resultWidgets.addAll(_buildCompanyResults(
              context, searchProvider.getResultsByType(indexName)));
          break;
        case "Associations":
          indexName = 'associations';
          resultWidgets.addAll(_buildAssociationResults(
              context, searchProvider.getResultsByType(indexName)));
          break;
        case "Posts":
          indexName = 'posts';
          resultWidgets.addAll(_buildPostResults(
              context, searchProvider.getResultsByType(indexName)));
          break;
      }
    }

    // Utiliser un ListView.builder pour une meilleure performance
    return ListView.builder(
      itemCount: resultWidgets.length,
      itemBuilder: (context, index) => resultWidgets[index],
      // Ajouter ces propriétés pour améliorer les performances
      cacheExtent: 1000, // Mettre en cache plus d'éléments
      addAutomaticKeepAlives: true, // Garder les éléments en vie
      addRepaintBoundaries: true, // Ajouter des limites de repeinture
    );
  }

  List<Widget> _buildUserResults(
      BuildContext context, List<Map<String, dynamic>> users) {
    return users.map((userData) {
      // Utiliser l'ID comme clé de cache
      final cacheKey = 'user_${userData['objectID']}';

      // Vérifier si le widget est déjà en cache
      if (_widgetCache.containsKey(cacheKey)) {
        return _widgetCache[cacheKey]!;
      }

      // Créer le widget et le mettre en cache
      final widget = ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(userData['image_profile'] ?? ''),
        ),
        title: Text(
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Profile(userId: userData['objectID']),
            ),
          );
        },
      );

      _widgetCache[cacheKey] = widget;
      return widget;
    }).toList();
  }

  List<Widget> _buildCompanyResults(
      BuildContext context, List<Map<String, dynamic>> companies) {
    return companies.map((companyData) {
      // Utiliser l'ID comme clé de cache
      final cacheKey = 'company_${companyData['objectID']}';

      // Vérifier si le widget est déjà en cache
      if (_widgetCache.containsKey(cacheKey)) {
        return _widgetCache[cacheKey]!;
      }

      // Récupérer les données complètes depuis Firestore
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('companys')
            .doc(companyData['objectID'])
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListTile(
              title: Text('Chargement...'),
              leading: CircleAvatar(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final widget = buildCompanyCard(snapshot.data!);
          _widgetCache[cacheKey] = widget;
          return widget;
        },
      );
    }).toList();
  }

  List<Widget> _buildAssociationResults(
      BuildContext context, List<Map<String, dynamic>> associations) {
    return associations.map((associationData) {
      // Utiliser l'ID comme clé de cache
      final cacheKey = 'association_${associationData['objectID']}';

      // Vérifier si le widget est déjà en cache
      if (_widgetCache.containsKey(cacheKey)) {
        return _widgetCache[cacheKey]!;
      }

      // Récupérer les données complètes depuis Firestore
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('companys')
            .doc(associationData['objectID'])
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListTile(
              title: Text('Chargement...'),
              leading: CircleAvatar(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          final widget = buildCompanyCard(snapshot.data!);
          _widgetCache[cacheKey] = widget;
          return widget;
        },
      );
    }).toList();
  }

  List<Widget> _buildPostResults(
      BuildContext context, List<Map<String, dynamic>> posts) {
    return posts.map((postData) {
      // Utiliser l'ID comme clé de cache
      final cacheKey = 'post_${postData['objectID']}';

      // Vérifier si le widget est déjà en cache
      if (_widgetCache.containsKey(cacheKey)) {
        return _widgetCache[cacheKey]!;
      }

      // Récupérer les données complètes depuis Firestore
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('posts')
            .doc(postData['objectID'])
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListTile(
              title: Text('Chargement...'),
              leading: CircleAvatar(child: CircularProgressIndicator()),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const SizedBox.shrink();
          }

          return FutureBuilder<Widget>(
            future: buildPostWidget(snapshot.data!),
            builder: (context, postWidgetSnapshot) {
              if (postWidgetSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const ListTile(
                  title: Text('Chargement du post...'),
                );
              }

              if (!postWidgetSnapshot.hasData) {
                return const SizedBox.shrink();
              }

              final widget = postWidgetSnapshot.data!;
              _widgetCache[cacheKey] = widget;
              return widget;
            },
          );
        },
      );
    }).toList();
  }

  // Les méthodes existantes pour construire les widgets restent inchangées
  Widget buildUserWidget(BuildContext context, DocumentSnapshot document) {
    Map<String, dynamic> userData = document.data() as Map<String, dynamic>;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(userData['image_profile'] ?? ''),
      ),
      title: Text('${userData['firstName']} ${userData['lastName']}'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Profile(userId: document.id),
          ),
        );
      },
    );
  }

  Widget buildCompanyCard(DocumentSnapshot document) {
    Company company = Company.fromDocument(document);
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: CompanyCard(company),
    );
  }

  Future<Widget> buildPostWidget(DocumentSnapshot document) async {
    Map<String, dynamic> data = document.data() as Map<String, dynamic>;
    Post post = Post.fromDocument(document);

    DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
        .collection('companys')
        .doc(data['companyId'])
        .get();

    if (!companySnapshot.exists) {
      return const SizedBox.shrink();
    }

    Map<String, dynamic> companyData =
        companySnapshot.data() as Map<String, dynamic>;

    return PostWidget(
      key: Key(document.id),
      post: post,
      companyData: CompanyData(
          category: companyData['categorie'] ?? '',
          cover: companyData['cover'] ?? '',
          logo: companyData['logo'] ?? '',
          name: companyData['name'] ?? 'Unknown',
          rawData: companyData),
      currentUserId: '',
      currentProfileUserId: '',
      onView: () {},
    );
  }

  Widget buildAssociationCard(DocumentSnapshot document) {
    Association association = Association.fromFirestore(document);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(association.logo),
              radius: 25,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          association.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (association.isVerified)
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    association.category,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Vider le cache lorsque le widget est supprimé
    _widgetCache.clear();
    super.dispose();
  }
}
