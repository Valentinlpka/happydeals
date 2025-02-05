import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Imports de vos classes
import 'package:happy/classes/company.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/loyalty_card.dart';
import 'package:happy/classes/loyalty_program.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/referral_options_modal.dart';
// Imports de vos providers et widgets
import 'package:happy/providers/company_provider.dart';
import 'package:happy/providers/review_service.dart';
import 'package:happy/screens/shop/product_list.dart';
import 'package:happy/widgets/company_message_bottom_sheet.dart';
import 'package:happy/widgets/opening_hours_widget.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/review_list.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailsEntreprise extends StatefulWidget {
  final String entrepriseId;

  const DetailsEntreprise({super.key, this.entrepriseId = ''});

  @override
  _DetailsEntrepriseState createState() => _DetailsEntrepriseState();
}

class _DetailsEntrepriseState extends State<DetailsEntreprise>
    with TickerProviderStateMixin {
  // Controllers
  final ScrollController _tabScrollController = ScrollController();

  // Futures pour les données
  late Future<LoyaltyProgram?> _loyaltyProgramFuture;
  late Future<LoyaltyCard?> _loyaltyCardFuture;
  late Future<Company> _entrepriseFuture;
  late Future<List<Map<String, dynamic>>> _postsFuture;

  // État de l'onglet courant
  String _currentTab = 'Boutique';

  // Liste des onglets disponibles
  final List<String> _tabs = [
    'Boutique',
    'Happy Deals',
    'Évenement',
    'Jeux concours',
    'Deal Express',
    "Offres d'emploi",
    'Parrainage',
    'Toutes les publications',
    'Avis',
    'À Propos'
  ];

  // Cache pour les données company
  final Map<String, Map<String, dynamic>> _companyDataCache = {};

  // Ajouter ces contrôleurs
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Initialiser le TabController
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Écouter les changements de tab
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabs[_tabController.index];
        });
      }
    });
  }

  void _initializeData() {
    _entrepriseFuture = _fetchEntrepriseData();
    _postsFuture = _fetchAllPosts();
    _loyaltyProgramFuture = _fetchLoyaltyProgram();
    _loyaltyCardFuture = _fetchLoyaltyCard();
  }

  @override
  void dispose() {
    _tabController.dispose(); // Nettoyer le contrôleur
    _tabScrollController.dispose();
    _companyDataCache.clear();
    super.dispose();
  }
  // ... code précédent ...

  // 1. Méthodes de récupération principales
  Future<Company> _fetchEntrepriseData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(widget.entrepriseId)
          .get();

      if (!doc.exists) {
        throw Exception('Entreprise non trouvée');
      }

      return Company.fromDocument(doc);
    } catch (e) {
      debugPrint('Erreur lors du chargement de l\'entreprise: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllPosts() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('companyId', isEqualTo: widget.entrepriseId)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> posts = [];
      for (var doc in querySnapshot.docs) {
        final post = _createPostFromDocument(doc);
        if (post != null) {
          final companyData = await _getCompanyData(post.companyId);
          posts.add({'post': post, 'company': companyData});
        }
      }
      return posts;
    } catch (e) {
      debugPrint('Erreur lors du chargement des posts: $e');
      return [];
    }
  }

  // 2. Méthodes de récupération des programmes de fidélité
  Future<LoyaltyProgram?> _fetchLoyaltyProgram() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('LoyaltyPrograms')
          .where('companyId', isEqualTo: widget.entrepriseId)
          .get();
      if (doc.docs.isNotEmpty) {
        return LoyaltyProgram.fromFirestore(doc.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors du chargement du programme de fidélité: $e');
      return null;
    }
  }

  Future<LoyaltyCard?> _fetchLoyaltyCard() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('LoyaltyCards')
          .where('customerId', isEqualTo: userId)
          .where('companyId', isEqualTo: widget.entrepriseId)
          .where('status', isEqualTo: 'active')
          .get();
      if (doc.docs.isNotEmpty) {
        return LoyaltyCard.fromFirestore(doc.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors du chargement de la carte de fidélité: $e');
      return null;
    }
  }

  // 3. Méthodes utilitaires
  Future<Map<String, dynamic>> _getCompanyData(String companyId) async {
    if (_companyDataCache.containsKey(companyId)) {
      return _companyDataCache[companyId]!;
    }

    DocumentSnapshot companyDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();
    final data = companyDoc.data() as Map<String, dynamic>;
    _companyDataCache[companyId] = data;
    return data;
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
          return null;
      }
    } catch (e) {
      debugPrint('Erreur lors de la création du post: $e');
      return null;
    }
  }

  String _getPostType(String tab) {
    final typeMap = {
      'Happy Deals': 'happy_deal',
      'Évenement': 'event',
      'Deal Express': 'express_deal',
      "Offres d'emploi": 'job_offer',
      'Parrainage': 'referral',
      'Jeux concours': 'contest',
    };
    return typeMap[tab] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) =>
                CompanyLikeService(FirebaseAuth.instance.currentUser!.uid)),
        ChangeNotifierProvider(create: (_) => ReviewService()),
      ],
      child: Scaffold(
        body: FutureBuilder<Company>(
          future: _entrepriseFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('Entreprise non trouvée'));
            }

            final entreprise = snapshot.data!;
            return DefaultTabController(
              length: _tabs.length,
              child: NestedScrollView(
                headerSliverBuilder:
                    (BuildContext context, bool innerBoxIsScrolled) {
                  return <Widget>[
                    SliverAppBar(
                      backgroundColor: Colors.grey[50],
                      elevation: 1,
                      pinned: true,
                      centerTitle: true,
                      titleSpacing: 0,
                      title: Text(
                        entreprise.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          color: Colors.black,
                        ),
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildCoverImage(entreprise),
                          _buildCompanyInfo(entreprise),
                          _buildActionButtons(entreprise),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    SliverPersistentHeader(
                        delegate: _StickyTabBarDelegate(
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            indicatorColor: const Color(0xFF0B7FE9),
                            indicatorWeight: 3,
                            labelColor: const Color(0xFF0B7FE9),
                            unselectedLabelColor: Colors.grey[600],
                            tabAlignment: TabAlignment.start,
                            tabs: _tabs.map((String tab) {
                              return Tab(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    tab,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        pinned: true),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) {
                    return _buildTabContent(tab, entreprise);
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCoverImage(Company entreprise) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Image.network(
        entreprise.cover,
        fit: BoxFit.cover,
        colorBlendMode: BlendMode.darken,
        color: Colors.black.withOpacity(0.2),
      ),
    );
  }

  Widget _buildCompanyInfo(Company entreprise) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
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
                  backgroundImage: NetworkImage(entreprise.logo),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entreprise.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    Text(entreprise.categorie),
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

          // Programme de fidélité
          FutureBuilder<LoyaltyProgram?>(
            future: _loyaltyProgramFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasData && snapshot.data != null) {
                return InkWell(
                  onTap: () => _showLoyaltyProgramDetails(snapshot.data!),
                  child: const Text(
                    "Programme de fidélité disponible",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
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

          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Impossible d\'ouvrir $url')),
              );
            }
          }
        },
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ... code précédent ...

  void _showLoyaltyProgramDetails(LoyaltyProgram program) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder<LoyaltyCard?>(
          future: _loyaltyCardFuture,
          builder: (context, cardSnapshot) {
            return SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Programme de fidélité",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_buildProgramDescription(program)),
                    const SizedBox(height: 16),
                    if (cardSnapshot.hasData && cardSnapshot.data != null)
                      Text(
                        "Votre progression : ${cardSnapshot.data!.currentValue} / ${program.targetValue}",
                        style: const TextStyle(fontSize: 16),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          cardSnapshot.hasData && cardSnapshot.data != null
                              ? "Voir ma carte"
                              : "S'inscrire",
                        ),
                        onPressed: () =>
                            cardSnapshot.hasData && cardSnapshot.data != null
                                ? _showLoyaltyCard(cardSnapshot.data!)
                                : _subscribeLoyaltyProgram(program),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _buildProgramDescription(LoyaltyProgram program) {
    switch (program.type) {
      case LoyaltyProgramType.visits:
        return "Après ${program.targetValue} visites, obtenez ${program.rewardValue}${program.isPercentage ? '%' : '€'} de réduction!";
      case LoyaltyProgramType.points:
        return "Gagnez des points à chaque achat. Paliers de récompenses :\n${program.tiers!.entries.map((e) => "${e.key} points = ${e.value}${program.isPercentage ? '%' : '€'}").join("\n")}";
      case LoyaltyProgramType.amount:
        return "Après ${program.targetValue}€ d'achats, obtenez ${program.rewardValue}${program.isPercentage ? '%' : '€'} de réduction!";
    }
  }

  void _showLoyaltyCard(LoyaltyCard card) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Ma carte de fidélité"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Progression actuelle : ${card.currentValue}"),
              const SizedBox(height: 16),
              // Vous pouvez ajouter d'autres détails ici
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Fermer"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _subscribeLoyaltyProgram(LoyaltyProgram program) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();
      final newCard = LoyaltyCard(
        id: '',
        customerId: userId,
        loyaltyProgramId: program.id,
        companyId: widget.entrepriseId,
        currentValue: 0,
        createdAt: now,
        lastUsed: now,
        lastTransaction: LastTransaction(
          date: now,
          amount: 0,
          type: 'earn',
        ),
        totalEarned: 0,
        totalRedeemed: 0,
        status: 'active',
      );
      final docRef = await FirebaseFirestore.instance
          .collection('LoyaltyCards')
          .add(newCard.toFirestore());

      setState(() {
        _loyaltyCardFuture = Future.value(newCard.copyWith(id: docRef.id));
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inscription au programme de fidélité réussie!'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Erreur lors de l\'inscription au programme de fidélité'),
          ),
        );
      }
      debugPrint('Erreur lors de l\'inscription: $e');
    }
  }
  // ... code précédent ...

  Widget _buildTabContent(String tab, Company entreprise) {
    switch (tab) {
      case 'Avis':
        return ReviewListWidget(companyId: entreprise.id);
      case 'À Propos':
        return _buildAboutTab(entreprise);
      case 'Boutique':
        return ProductList(sellerId: entreprise.sellerId);
      case 'Parrainage':
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildReferralSection(entreprise),
              _buildReferralPosts(),
            ],
          ),
        );
      default:
        return _buildFilteredPostList();
    }
  }

  Widget _buildReferralSection(Company entreprise) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Programme de Parrainage',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Parrainez de nouveaux clients et bénéficiez d\'avantages exclusifs !',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.people_outline, color: Colors.white),
              label: const Text(
                'Parrainer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => _showReferralOptionsModal(entreprise),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralPosts() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text('Erreur: ${snapshot.error ?? "Aucun post trouvé"}'),
          );
        }

        final allPosts = snapshot.data!;
        final referralPosts = allPosts
            .where((postData) => (postData['post'] as Post).type == 'referral')
            .toList();

        if (referralPosts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Aucune offre de parrainage publiée pour le moment',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.all(10),
          itemCount: referralPosts.length,
          itemBuilder: (context, index) {
            final postData = referralPosts[index];
            final post = postData['post'] as Post;
            final companyData = postData['company'] as Map<String, dynamic>;

            return PostWidget(
              key: ValueKey(post.id),
              post: post,
              companyCover: companyData['cover'],
              companyCategorie: companyData['categorie'] ?? '',
              companyName: companyData['name'] ?? '',
              companyLogo: companyData['logo'] ?? '',
              companyData: companyData,
              currentUserId: FirebaseAuth.instance.currentUser!.uid,
              currentProfileUserId: FirebaseAuth.instance.currentUser!.uid,
              onView: () {
                // Logique d'affichage
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilteredPostList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text('Erreur: ${snapshot.error ?? "Aucun post trouvé"}'),
          );
        }

        final allPosts = snapshot.data!;
        final filteredPosts = _currentTab == 'Toutes les publications'
            ? allPosts
            : allPosts
                .where((postData) =>
                    (postData['post'] as Post).type ==
                    _getPostType(_currentTab))
                .toList();

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.all(10),
          itemCount: filteredPosts.length,
          itemBuilder: (context, index) {
            final postData = filteredPosts[index];
            final post = postData['post'] as Post;
            final companyData = postData['company'] as Map<String, dynamic>;

            return PostWidget(
              key: ValueKey(post.id),
              post: post,
              companyCover: companyData['cover'],
              companyCategorie: companyData['categorie'] ?? '',
              companyName: companyData['name'] ?? '',
              companyLogo: companyData['logo'] ?? '',
              companyData: companyData,
              currentUserId: FirebaseAuth.instance.currentUser!.uid,
              currentProfileUserId: FirebaseAuth.instance.currentUser!.uid,
              onView: () {
                // Logique d'affichage
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons(Company entreprise) {
    return Consumer<CompanyLikeService>(
      builder: (context, companyLikeService, child) {
        final isFollowed = companyLikeService.isCompanyLiked(entreprise.id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isFollowed
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    color: isFollowed ? Colors.white : null,
                    border: Border.all(
                      color: isFollowed
                          ? const Color(0xFF0B7FE9)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      if (!isFollowed)
                        BoxShadow(
                          color: const Color(0xFF0B7FE9).withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final updatedCompany =
                            await companyLikeService.handleLike(entreprise);
                        setState(() {
                          _entrepriseFuture = Future.value(updatedCompany);
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFollowed
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            size: 20,
                            color: isFollowed
                                ? const Color(0xFF0B7FE9)
                                : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isFollowed ? 'Suivi' : 'Suivre',
                            style: TextStyle(
                              color: isFollowed
                                  ? const Color(0xFF0B7FE9)
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B7FE9).withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _startConversation(
                      context,
                      entreprise,
                      FirebaseAuth.instance.currentUser!.uid,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutTab(Company entreprise) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('Description', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(entreprise.description),
        const SizedBox(height: 16),
        Text('Horaires d\'ouverture',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        OpeningHoursWidget(openingHours: entreprise.openingHours),
      ],
    );
  }

  void _startConversation(
      BuildContext context, Company company, String currentUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CompanyMessageBottomSheet(
        company: company,
        currentUserId: currentUserId,
      ),
    );
  }

  void _showReferralOptionsModal(Company entreprise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ReferralOptionsModal(
              companyId: entreprise.id,
              referralId: '',
            ),
          ),
        );
      },
    );
  }
}

// Ajouter cette classe en dehors de la classe principale
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.grey[50],
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return false;
  }
}
