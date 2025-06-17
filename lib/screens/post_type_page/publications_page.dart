import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/postwidget.dart';

class PublicationsPage extends StatefulWidget {
  const PublicationsPage({super.key});

  @override
  State<PublicationsPage> createState() => _PublicationsPageState();
}

class _PublicationsPageState extends State<PublicationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Tous';
  List<String> _categories = ['Tous'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('type', isEqualTo: 'news')
          .get();

      Set<String> categoriesSet = {'Tous'};

      for (var doc in postsSnapshot.docs) {
        final data = doc.data();
        if (data['category'] != null) {
          categoriesSet.add(data['category'] as String);
        }
      }

      setState(() {
        _categories = categoriesSet.toList()..sort();
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des catégories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Publications',
        align: Alignment.center,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_selectedCategory != 'Tous') _buildSelectedFilter(),
          Expanded(
            child: _buildPublicationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher une publication...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4B88DA)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildSelectedFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            label: Text(_selectedCategory),
            onSelected: (_) {},
            selected: true,
            onDeleted: () {
              setState(() {
                _selectedCategory = 'Tous';
              });
            },
            deleteIcon: const Icon(Icons.close, size: 18, color: Colors.white),
            backgroundColor: const Color(0xFF4B88DA),
            selectedColor: const Color(0xFF4B88DA),
            labelStyle: const TextStyle(color: Colors.white),
            showCheckmark: false,
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtres',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCategory = 'Tous';
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Catégorie'),
                        value: _selectedCategory == 'Tous'
                            ? null
                            : _selectedCategory,
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setModalState(() {
                              _selectedCategory = newValue;
                            });
                          }
                        },
                        items: _categories.map((String item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B88DA),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Appliquer les filtres',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPublicationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('posts')
          .where('type', isEqualTo: 'news')
          .where('isActive', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucune publication disponible'));
        }

        final publications = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5.0),
          itemCount: publications.length,
          itemBuilder: (context, index) {
            final publicationData =
                publications[index].data() as Map<String, dynamic>;

            if (!_matchesFilters(publicationData)) {
              return const SizedBox.shrink();
            }

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore
                  .collection('companys')
                  .doc(publicationData['companyId'])
                  .get(),
              builder: (context, companySnapshot) {
                if (!companySnapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final companyData =
                    companySnapshot.data?.data() as Map<String, dynamic>?;

                if (companyData == null) {
                  return const SizedBox.shrink();
                }

                final companyDataObj = CompanyData(
                  name: companyData['name'] ?? 'Nom inconnu',
                  category: companyData['category'] ?? '',
                  logo: companyData['logo'] ?? '',
                  cover: companyData['cover'] ?? '',
                  rawData: companyData,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PostWidget(
                    post: Post.fromDocument(publications[index]),
                    currentUserId: '',
                    currentProfileUserId: '',
                    onView: () {},
                    companyData: companyDataObj,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  bool _matchesFilters(Map<String, dynamic> publicationData) {
    final searchText = _searchController.text.toLowerCase();
    if (searchText.isNotEmpty &&
        !publicationData['title']
            .toString()
            .toLowerCase()
            .contains(searchText) &&
        !publicationData['description']
            .toString()
            .toLowerCase()
            .contains(searchText)) {
      return false;
    }

    if (_selectedCategory != 'Tous' &&
        publicationData['category'] != _selectedCategory) {
      return false;
    }

    return true;
  }
}
