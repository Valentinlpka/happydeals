import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/company_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/screens/shop/product_grid.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:happy/widgets/opening_hours_widget.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/review_list.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailsEntreprise extends StatefulWidget {
  final String entrepriseId;

  const DetailsEntreprise({super.key, required this.entrepriseId});

  @override
  _DetailsEntrepriseState createState() => _DetailsEntrepriseState();
}

class _DetailsEntrepriseState extends State<DetailsEntreprise> {
  late Future<Company> _entrepriseFuture;
  late PagingController<DocumentSnapshot?, Map<String, dynamic>>
      _pagingController;
  String _currentTab = 'Toutes les publications';
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _entrepriseFuture = _fetchEntrepriseData();
    _pagingController = PagingController(firstPageKey: null);
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  Future<Company> _fetchEntrepriseData() async {
    final doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(widget.entrepriseId)
        .get();
    return Company.fromDocument(doc);
  }

  Post? _createPostFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String type = data['type'] ?? 'unknown';

    try {
      switch (type) {
        case 'job_offer':
          return JobOffer.fromDocument(doc);
        case 'contest':
          return Contest.fromDocument(doc);
        case 'happy_deal':
          return HappyDeal.fromDocument(doc);
        case 'express_deal':
          return ExpressDeal.fromDocument(doc);
        case 'referral':
          return Referral.fromDocument(doc);
        case 'event':
          return Event.fromDocument(doc);
        default:
          print("Type de post non supporté: $type pour le document ${doc.id}");
          return null;
      }
    } catch (e) {
      print("Erreur lors de la création du post de type $type: $e");
      return null;
    }
  }

  Future<void> _fetchPage(DocumentSnapshot? pageKey) async {
    try {
      print(_getPostType(_currentTab));
      Query query = FirebaseFirestore.instance
          .collection('posts')
          .where('companyId', isEqualTo: widget.entrepriseId)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      if (_currentTab != 'Toutes les publications' &&
          _currentTab != 'Boutique') {
        query = query.where('type', isEqualTo: _getPostType(_currentTab));
      }

      if (pageKey != null) {
        query = query.startAfterDocument(pageKey);
      }

      final querySnapshot = await query.get();
      final List<Map<String, dynamic>> newPosts = [];

      for (var doc in querySnapshot.docs) {
        final post = _createPostFromDocument(doc);
        if (post != null) {
          final companyData = await _getCompanyData(post.companyId);
          newPosts.add({
            'post': post,
            'company': companyData,
          });
        }
      }

      final isLastPage = newPosts.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newPosts);
      } else {
        final lastDocument = querySnapshot.docs.last;
        _pagingController.appendPage(newPosts, lastDocument);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  String _getPostType(String tab) {
    switch (tab) {
      case 'Happy Deals':
        return 'happy_deal';
      case 'Évenement':
        return 'event';
      case 'Deal Express':
        return 'express_deal';
      case "Offres d'emploi":
        return 'job_offer';
      case 'Happy Deal':
        return 'happy_deal';
      case 'Parrainage':
        return 'referral';
      case 'Jeux concours':
        return 'contest';
      default:
        return '';
    }
  }

  Future<Map<String, dynamic>> _getCompanyData(String companyId) async {
    DocumentSnapshot companyDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();
    return companyDoc.data() as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CompanyLikeService(FirebaseAuth.instance.currentUser!.uid),
      child: Scaffold(
        body: FutureBuilder<Company>(
          future: _entrepriseFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                  child: Text(
                      'Erreur: ${snapshot.error ?? "Entreprise non trouvée"}'));
            }

            final entreprise = snapshot.data!;
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(entreprise),
                SliverToBoxAdapter(child: _buildCompanyInfo(entreprise)),
                SliverToBoxAdapter(child: _buildActionButtons(entreprise)),
                SliverToBoxAdapter(child: _buildTabBar()),
                SliverFillRemaining(child: _buildTabContent(entreprise)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ... (autres méthodes inchangées)

  Widget _buildSliverAppBar(Company entreprise) {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      primary: true,
      flexibleSpace: FlexibleSpaceBar(
        background: CachedNetworkImage(
          imageUrl: entreprise.cover,
          colorBlendMode: BlendMode.darken,
          color: Colors.black.withOpacity(0.20),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          'Toutes les publications',
          'Boutique',
          'Happy Deals',
          'Évenement',
          'Jeux concours',
          'Deal Express',
          "Offres d'emploi",
          'Parrainage',
          'Avis',
          'À Propos'
        ].map((tab) => _buildTab(tab)).toList(),
      ),
    );
  }

  Widget _buildTab(String tabName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _currentTab == tabName
                ? [const Color(0xFF3476B2), const Color(0xFF0B7FE9)]
                : [Colors.transparent, Colors.transparent],
            stops: const [0.0, 1.0],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _currentTab = tabName;
              _pagingController.refresh();
            });
          },
          style: ElevatedButton.styleFrom(
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
          ),
          child: Text(
            tabName,
            style: TextStyle(
                color: _currentTab == tabName ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyInfo(Company entreprise) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.blue,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: CachedNetworkImageProvider(entreprise.logo),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizeFirstLetter(entreprise.name),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    Text(capitalizeFirstLetter(entreprise.categorie)),
                    Text('${entreprise.like} J\'aime'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(entreprise.description),
          const SizedBox(height: 8),
          _buildInfoTile(Icons.language, 'google.fr'),
          _buildInfoTile(Icons.location_on,
              "${entreprise.adress.adresse} ${entreprise.adress.codePostal} ${entreprise.adress.ville}"),
          _buildInfoTile(Icons.phone, entreprise.phone),
          _buildInfoTile(Icons.email, entreprise.email),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () async {
          String url;
          if (icon == Icons.phone) {
            url = 'tel:$text';
          } else if (icon == Icons.email) {
            url = 'mailto:$text';
          } else if (icon == Icons.language) {
            url = text.startsWith('http') ? text : 'https://$text';
          } else {
            url = 'https://www.google.com/maps/search/?api=1&query=$text';
          }
          if (await canLaunch(url)) {
            await launch(url);
          }
        },
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(Company entreprise) {
    switch (_currentTab) {
      case 'Avis':
        return ReviewList(companyId: widget.entrepriseId);
      case 'À Propos':
        return _buildAboutTab(entreprise);
      case 'Boutique':
        return ProductGrid(sellerId: entreprise.sellerId);
      default:
        return _buildPostList();
    }
  }

  Widget _buildPostList() {
    return PagedListView<DocumentSnapshot?, Map<String, dynamic>>(
      pagingController: _pagingController,
      physics: const NeverScrollableScrollPhysics(),
      builderDelegate: PagedChildBuilderDelegate<Map<String, dynamic>>(
        noItemsFoundIndicatorBuilder: (_) => const Center(
          child: Text('Aucun post trouvé', textAlign: TextAlign.center),
        ),
        itemBuilder: (context, postData, index) {
          print('Building post at index $index');
          final post = postData['post'] as Post;
          final companyData = postData['company'] as Map<String, dynamic>;

          print('Post ID: ${post.id}');
          print('Post Type: ${post.type}');
          print('Company: ${companyData['name']}');

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0),
            child: PostWidget(
              key: ValueKey(post.id),
              post: post,
              companyCategorie: companyData['categorie'] ?? '',
              companyName: companyData['name'] ?? '',
              companyLogo: companyData['logo'] ?? '',
              currentUserId: FirebaseAuth.instance.currentUser!.uid,
              onView: () {
                // Logique d'affichage
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAboutTab(Company entreprise) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('Description', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(entreprise.description),
        const SizedBox(height: 16),
        Text('Horaires d\'ouverture',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        OpeningHoursWidget(openingHours: entreprise.openingHours)
      ],
    );
  }

  void _startConversation(
      BuildContext context, Company company, String currentUserId) async {
    final conversationService =
        Provider.of<ConversationService>(context, listen: false);
    final String conversationId = await conversationService
        .getOrCreateConversation(currentUserId, company.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationDetailScreen(
          otherUserName: company.name,
          conversationId: conversationId,
        ),
      ),
    );
  }

  Widget _buildActionButtons(Company entreprise) {
    return Consumer<CompanyLikeService>(
      builder: (context, companyLikeService, child) {
        final isLiked = companyLikeService.isCompanyLiked(entreprise.id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                      stops: [0.0, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shadowColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                    ),
                    onPressed: () async {
                      final updatedCompany =
                          await companyLikeService.handleLike(entreprise);
                      setState(() {
                        _entrepriseFuture = Future.value(updatedCompany);
                      });
                    },
                    child: Text(isLiked ? 'Aimé' : 'Aimer l\'entreprise'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                      stops: [0.0, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ElevatedButton(
                    onPressed: () => _startConversation(context, entreprise,
                        FirebaseAuth.instance.currentUser!.uid),
                    style: ElevatedButton.styleFrom(
                      shadowColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                    ),
                    child: const Text('Envoyer un message'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  // ... (autres méthodes inchangées)
}
