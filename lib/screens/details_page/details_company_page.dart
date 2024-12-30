import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
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

class _DetailsEntrepriseState extends State<DetailsEntreprise> {
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

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _entrepriseFuture = _fetchEntrepriseData();
    _postsFuture = _fetchAllPosts();
    _loyaltyProgramFuture = _fetchLoyaltyProgram();
    _loyaltyCardFuture = _fetchLoyaltyCard();
  }

  @override
  void dispose() {
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

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                  child: Text(
                      'Erreur: ${snapshot.error ?? "Entreprise non trouvée"}'));
            }

            final entreprise = snapshot.data!;
            return NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  _buildSliverAppBar(entreprise),
                  _buildCoverImage(entreprise),
                  SliverToBoxAdapter(child: _buildCompanyInfo(entreprise)),
                  SliverToBoxAdapter(child: _buildActionButtons(entreprise)),
                  SliverToBoxAdapter(child: _buildTabBar()),
                ];
              },
              body: _buildTabContent(entreprise),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Company entreprise) {
    return SliverAppBar(
      backgroundColor: Colors.white,
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
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.grey[300],
        ),
      ),
    );
  }

  Widget _buildCoverImage(Company entreprise) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Image.network(
          entreprise.cover,
          fit: BoxFit.cover,
          colorBlendMode: BlendMode.darken,
          color: Colors.black.withOpacity(0.2),
        ),
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
      final newCard = LoyaltyCard(
        id: '',
        customerId: userId,
        loyaltyProgramId: program.id,
        companyId: widget.entrepriseId,
        currentValue: 0,
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

  Widget _buildTabBar() {
    return SizedBox(
      height: 55,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final double scrollDelta = pointerSignal.scrollDelta.dy;
            _tabScrollController.position.moveTo(
              _tabScrollController.position.pixels + scrollDelta,
              curve: Curves.linear,
              duration: const Duration(milliseconds: 100),
            );
          }
        },
        child: SingleChildScrollView(
          controller: _tabScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _tabs.map((tab) => _buildTab(tab)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String tabName) {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: Container(
        height: 35,
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
          onPressed: () => setState(() => _currentTab = tabName),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          child: Text(
            tabName,
            style: TextStyle(
              color: _currentTab == tabName ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(Company entreprise) {
    switch (_currentTab) {
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
  } // ... code précédent ...

  Widget _buildActionButtons(Company entreprise) {
    return Consumer<CompanyLikeService>(
      builder: (context, companyLikeService, child) {
        final isFollowed = companyLikeService.isCompanyLiked(entreprise.id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isFollowed ? Colors.white : const Color(0xFF0B7FE9),
                    border: Border.all(
                      color: isFollowed
                          ? const Color(0xFF0B7FE9)
                          : Colors.transparent,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      if (!isFollowed)
                        BoxShadow(
                          color: const Color(0xFF0B7FE9).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final updatedCompany =
                            await companyLikeService.handleLike(entreprise);
                        setState(() {
                          _entrepriseFuture = Future.value(updatedCompany);
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFollowed
                                    ? 'Vous ne suivez plus ${entreprise.name}'
                                    : 'Vous suivez maintenant ${entreprise.name}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              margin: const EdgeInsets.all(10),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFollowed ? Icons.check_circle : Icons.add,
                            size: 18,
                            color: isFollowed
                                ? const Color(0xFF0B7FE9)
                                : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFollowed ? 'Suivi' : 'Suivre',
                            style: TextStyle(
                              color: isFollowed
                                  ? const Color(0xFF0B7FE9)
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B7FE9).withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _startConversation(
                        context,
                        entreprise,
                        FirebaseAuth.instance.currentUser!.uid,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Message',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
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

// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';
// import 'package:happy/classes/company.dart';
// import 'package:happy/classes/contest.dart';
// import 'package:happy/classes/dealexpress.dart';
// import 'package:happy/classes/event.dart';
// import 'package:happy/classes/happydeal.dart';
// import 'package:happy/classes/joboffer.dart';
// import 'package:happy/classes/loyalty_card.dart';
// import 'package:happy/classes/loyalty_program.dart';
// import 'package:happy/classes/post.dart';
// import 'package:happy/classes/referral.dart';
// import 'package:happy/classes/referral_options_modal.dart';
// import 'package:happy/providers/company_provider.dart';
// import 'package:happy/providers/review_service.dart';
// import 'package:happy/screens/shop/product_list.dart';
// import 'package:happy/widgets/company_message_bottom_sheet.dart';
// import 'package:happy/widgets/opening_hours_widget.dart';
// import 'package:happy/widgets/postwidget.dart';
// import 'package:happy/widgets/review_list.dart';
// import 'package:provider/provider.dart';
// import 'package:url_launcher/url_launcher.dart';

// class DetailsEntreprise extends StatefulWidget {
//   final String entrepriseId;

//   const DetailsEntreprise({super.key, this.entrepriseId = ''});

//   @override
//   _DetailsEntrepriseState createState() => _DetailsEntrepriseState();
// }

// class _DetailsEntrepriseState extends State<DetailsEntreprise> {
//   final ScrollController _tabScrollController = ScrollController();

//   late Future<LoyaltyProgram?> _loyaltyProgramFuture;

//   late Future<LoyaltyCard?> _loyaltyCardFuture;

//   late Future<Company> _entrepriseFuture;

//   late Future<List<Map<String, dynamic>>> _postsFuture;

//   String _currentTab = 'Boutique';

//   final List<String> _tabs = [
//     'Boutique',
//     'Happy Deals',
//     'Évenement',
//     'Jeux concours',
//     'Deal Express',
//     "Offres d'emploi",
//     'Parrainage',
//     'Toutes les publications',
//     'Avis',
//     'À Propos'
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _entrepriseFuture = _fetchEntrepriseData();
//     _postsFuture = _fetchAllPosts();
//     _loyaltyProgramFuture = _fetchLoyaltyProgram();
//     _loyaltyCardFuture = _fetchLoyaltyCard();
//   }

//   @override
//   void dispose() {
//     _tabScrollController.dispose();
//     super.dispose();
//   }

//   Widget _buildReferralSection(Company entreprise) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Programme de Parrainage',
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           const Text(
//             'Parrainez de nouveaux clients et bénéficiez d\'avantages exclusifs !',
//             style: TextStyle(
//               color: Colors.grey,
//               fontSize: 14,
//             ),
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton.icon(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue[800],
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               icon: const Icon(Icons.people_outline, color: Colors.white),
//               label: const Text(
//                 'Parrainer',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               onPressed: () => _showReferralOptionsModal(entreprise),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showReferralOptionsModal(Company entreprise) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (BuildContext context) {
//         return SingleChildScrollView(
//           child: Container(
//             padding: EdgeInsets.only(
//               bottom: MediaQuery.of(context).viewInsets.bottom,
//             ),
//             child: ReferralOptionsModal(
//               companyId: entreprise.id,
//               referralId:
//                   '', // Pas besoin d'ID de référence pour un parrainage direct
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Future<LoyaltyProgram?> _fetchLoyaltyProgram() async {
//     final doc = await FirebaseFirestore.instance
//         .collection('LoyaltyPrograms')
//         .where('companyId', isEqualTo: widget.entrepriseId)
//         .get();
//     if (doc.docs.isNotEmpty) {
//       return LoyaltyProgram.fromFirestore(doc.docs.first);
//     }
//     return null;
//   }

//   Future<LoyaltyCard?> _fetchLoyaltyCard() async {
//     final userId = FirebaseAuth.instance.currentUser!.uid;
//     final doc = await FirebaseFirestore.instance
//         .collection('LoyaltyCards')
//         .where('customerId', isEqualTo: userId)
//         .where('companyId', isEqualTo: widget.entrepriseId)
//         .get();
//     if (doc.docs.isNotEmpty) {
//       return LoyaltyCard.fromFirestore(doc.docs.first);
//     }
//     return null;
//   }

//   Future<Company> _fetchEntrepriseData() async {
//     final doc = await FirebaseFirestore.instance
//         .collection('companys')
//         .doc(widget.entrepriseId)
//         .get();
//     return Company.fromDocument(doc);
//   }

//   Future<List<Map<String, dynamic>>> _fetchAllPosts() async {
//     final querySnapshot = await FirebaseFirestore.instance
//         .collection('posts')
//         .where('companyId', isEqualTo: widget.entrepriseId)
//         .orderBy('timestamp', descending: true)
//         .get();

//     List<Map<String, dynamic>> posts = [];
//     for (var doc in querySnapshot.docs) {
//       final post = _createPostFromDocument(doc);
//       if (post != null) {
//         final companyData = await _getCompanyData(post.companyId);
//         posts.add({'post': post, 'company': companyData});
//       }
//     }
//     return posts;
//   }

//   Post? _createPostFromDocument(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     final String type = data['type'] ?? 'unknown';

//     try {
//       switch (type) {
//         case 'job_offer':
//           return JobOffer.fromDocument(doc);
//         case 'contest':
//           return Contest.fromDocument(doc);
//         case 'happy_deal':
//           return HappyDeal.fromDocument(doc);
//         case 'express_deal':
//           return ExpressDeal.fromDocument(doc);
//         case 'referral':
//           return Referral.fromDocument(doc);
//         case 'event':
//           return Event.fromDocument(doc);
//         default:
//           return null;
//       }
//     } catch (e) {
//       return null;
//     }
//   }

//   Future<Map<String, dynamic>> _getCompanyData(String companyId) async {
//     DocumentSnapshot companyDoc = await FirebaseFirestore.instance
//         .collection('companys')
//         .doc(companyId)
//         .get();
//     return companyDoc.data() as Map<String, dynamic>;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider(
//             create: (_) =>
//                 CompanyLikeService(FirebaseAuth.instance.currentUser!.uid)),
//         ChangeNotifierProvider(create: (_) => ReviewService()),
//       ],
//       child: Scaffold(
//         body: FutureBuilder<Company>(
//           future: _entrepriseFuture,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             }
//             if (snapshot.hasError || !snapshot.hasData) {
//               return Center(
//                   child: Text(
//                       'Erreur: ${snapshot.error ?? "Entreprise non trouvée"}'));
//             }

//             final entreprise = snapshot.data!;
//             return NestedScrollView(
//               headerSliverBuilder:
//                   (BuildContext context, bool innerBoxIsScrolled) {
//                 return <Widget>[
//                   _buildSliverAppBar(entreprise),
//                   SliverToBoxAdapter(
//                     child: SizedBox(
//                       height: 200, // Hauteur fixe pour l'image de couverture
//                       width: double.infinity,
//                       child: CachedNetworkImage(
//                         imageUrl: entreprise.cover,
//                         fit: BoxFit.cover,
//                         colorBlendMode: BlendMode.darken,
//                         color: Colors.black.withOpacity(0.2),
//                       ),
//                     ),
//                   ),
//                   SliverToBoxAdapter(child: _buildCompanyInfo(entreprise)),
//                   SliverToBoxAdapter(child: _buildActionButtons(entreprise)),
//                   SliverToBoxAdapter(child: _buildTabBar()),
//                 ];
//               },
//               body: _buildTabContent(entreprise),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   Widget _buildSliverAppBar(Company entreprise) {
//     return SliverAppBar(
//       backgroundColor: Colors.white,
//       elevation: 1,
//       pinned: true,
//       centerTitle: true,
//       titleSpacing: 0,
//       title: Text(
//         entreprise.name,
//         style: const TextStyle(
//           fontWeight: FontWeight.w600,
//           fontSize: 20,
//           color: Colors.black,
//         ),
//       ),
//       leading: IconButton(
//         icon: const Icon(
//           Icons.arrow_back_ios_new,
//           color: Colors.black,
//         ),
//         onPressed: () => Navigator.pop(context),
//       ),
//       bottom: PreferredSize(
//         preferredSize: const Size.fromHeight(1),
//         child: Container(
//           height: 1,
//           color: Colors.grey[300],
//         ),
//       ),
//     );
//   }

//   Widget _buildTabBar() {
//     return SizedBox(
//       height: 55, // Ajustez cette valeur selon vos besoins
//       child: Listener(
//         onPointerSignal: (pointerSignal) {
//           if (pointerSignal is PointerScrollEvent) {
//             final double scrollDelta = pointerSignal.scrollDelta.dy;
//             _tabScrollController.position.moveTo(
//               _tabScrollController.position.pixels + scrollDelta,
//               curve: Curves.linear,
//               duration: const Duration(milliseconds: 100),
//             );
//           }
//         },
//         child: SingleChildScrollView(
//           controller: _tabScrollController,
//           scrollDirection: Axis.horizontal,
//           child: Row(
//             children: _tabs.map((tab) => _buildTab(tab)).toList(),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTab(String tabName) {
//     return Padding(
//       padding: const EdgeInsets.only(left: 15),
//       child: Container(
//         height: 35,
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: _currentTab == tabName
//                 ? [const Color(0xFF3476B2), const Color(0xFF0B7FE9)]
//                 : [Colors.transparent, Colors.transparent],
//             stops: const [0.0, 1.0],
//             begin: Alignment.centerLeft,
//             end: Alignment.centerRight,
//           ),
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: ElevatedButton(
//           onPressed: () => setState(() => _currentTab = tabName),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.transparent,
//             shadowColor: Colors.transparent,
//           ),
//           child: Text(
//             tabName,
//             style: TextStyle(
//               color: _currentTab == tabName ? Colors.white : Colors.black,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildCompanyInfo(Company entreprise) {
//     return Padding(
//       padding: const EdgeInsets.all(15.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 42,
//                 backgroundColor: Colors.blue,
//                 child: CircleAvatar(
//                   radius: 40,
//                   backgroundImage: CachedNetworkImageProvider(entreprise.logo),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       (entreprise.name),
//                       style: const TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 28,
//                       ),
//                     ),
//                     Text((entreprise.categorie)),
//                     Text('${entreprise.like} J\'aime'),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Text(entreprise.description),
//           const SizedBox(height: 8),
//           _buildInfoTile(Icons.language, 'google.fr'),
//           _buildInfoTile(Icons.location_on,
//               "${entreprise.adress.adresse} ${entreprise.adress.codePostal} ${entreprise.adress.ville}"),
//           _buildInfoTile(Icons.phone, entreprise.phone),
//           _buildInfoTile(Icons.email, entreprise.email),
//           FutureBuilder<LoyaltyProgram?>(
//             future: _loyaltyProgramFuture,
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const CircularProgressIndicator();
//               }
//               if (snapshot.hasData && snapshot.data != null) {
//                 return InkWell(
//                   onTap: () => _showLoyaltyProgramDetails(snapshot.data!),
//                   child: const Text(
//                     "Programme de fidélité disponible",
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: Colors.green,
//                     ),
//                   ),
//                 );
//               }
//               return const SizedBox.shrink();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   void _showLoyaltyProgramDetails(LoyaltyProgram program) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext context) {
//         return FutureBuilder<LoyaltyCard?>(
//           future: _loyaltyCardFuture,
//           builder: (context, cardSnapshot) {
//             return SingleChildScrollView(
//               child: Container(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Text(
//                       "Programme de fidélité",
//                     ),
//                     const SizedBox(height: 16),
//                     Text(_buildProgramDescription(program)),
//                     const SizedBox(height: 16),
//                     if (cardSnapshot.hasData && cardSnapshot.data != null)
//                       Text(
//                           "Votre progression : ${cardSnapshot.data!.currentValue} / ${program.targetValue}"),
//                     const SizedBox(height: 16),
//                     ElevatedButton(
//                       child: Text(
//                           cardSnapshot.hasData && cardSnapshot.data != null
//                               ? "Voir ma carte"
//                               : "S'inscrire"),
//                       onPressed: () =>
//                           cardSnapshot.hasData && cardSnapshot.data != null
//                               ? _showLoyaltyCard(cardSnapshot.data!)
//                               : _subscribeLoyaltyProgram(program),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   String _buildProgramDescription(LoyaltyProgram program) {
//     switch (program.type) {
//       case LoyaltyProgramType.visits:
//         return "Après ${program.targetValue} visites, obtenez ${program.rewardValue}${program.isPercentage ? '%' : '€'} de réduction!";
//       case LoyaltyProgramType.points:
//         return "Gagnez des points à chaque achat. Paliers de récompenses :\n${program.tiers!.entries.map((e) => "${e.key} points = ${e.value}${program.isPercentage ? '%' : '€'}").join("\n")}";
//       case LoyaltyProgramType.amount:
//         return "Après ${program.targetValue}€ d'achats, obtenez ${program.rewardValue}${program.isPercentage ? '%' : '€'} de réduction!";
//     }
//   }

//   void _showLoyaltyCard(LoyaltyCard card) {
//     // Afficher les détails de la carte de fidélité
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text("Ma carte de fidélité"),
//           content: Text("Progression actuelle : ${card.currentValue}"),
//           actions: [
//             TextButton(
//               child: const Text("Fermer"),
//               onPressed: () => Navigator.of(context).pop(),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   void _subscribeLoyaltyProgram(LoyaltyProgram program) async {
//     final userId = FirebaseAuth.instance.currentUser!.uid;

//     // Créer une nouvelle carte de fidélité
//     final newCard = LoyaltyCard(
//       id: '', // Sera généré par Firestore
//       customerId: userId,
//       loyaltyProgramId: program.id,
//       companyId: widget.entrepriseId,
//       currentValue: 0,
//     );

//     try {
//       // Ajouter la carte à Firestore
//       final docRef = await FirebaseFirestore.instance
//           .collection('LoyaltyCards')
//           .add(newCard.toFirestore());

//       // Mettre à jour l'état local
//       setState(() {
//         _loyaltyCardFuture = Future.value(newCard.copyWith(id: docRef.id));
//       });

//       // Afficher un message de succès
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content: Text('Inscription au programme de fidélité réussie!')),
//       );

//       // Fermer le bottom sheet
//       Navigator.of(context).pop();
//     } catch (e) {
//       // Gérer les erreurs
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//             content:
//                 Text('Erreur lors de l\'inscription au programme de fidélité')),
//       );
//     }
//   }

//   Widget _buildInfoTile(IconData icon, String text) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: InkWell(
//         onTap: () async {
//           String url;
//           if (icon == Icons.phone) {
//             url = 'tel:$text';
//           } else if (icon == Icons.email) {
//             url = 'mailto:$text';
//           } else if (icon == Icons.language) {
//             url = text.startsWith('http') ? text : 'https://$text';
//           } else {
//             url = 'https://www.google.com/maps/search/?api=1&query=$text';
//           }
//           if (await canLaunchUrl(Uri.parse(url))) {
//             launchUrl(Uri.parse(url));
//           } else {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(content: Text('Impossible d\'ouvrir $url')),
//             );
//           }
//         },
//         child: Row(
//           children: [
//             Icon(icon, size: 16, color: Colors.grey),
//             const SizedBox(width: 8),
//             Expanded(
//               child: Text(text,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(color: Colors.grey)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTabContent(Company entreprise) {
//     switch (_currentTab) {
//       case 'Avis':
//         return ReviewListWidget(companyId: entreprise.id);
//       case 'À Propos':
//         return _buildAboutTab(entreprise);
//       case 'Boutique':
//         return ProductList(sellerId: entreprise.sellerId);
//       case 'Parrainage':
//         return SingleChildScrollView(
//           child: Column(
//             children: [
//               // Bouton de parrainage en haut
//               _buildReferralSection(entreprise),

//               // Liste des posts de parrainage en dessous
//               FutureBuilder<List<Map<String, dynamic>>>(
//                 future: _postsFuture,
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator());
//                   }
//                   if (snapshot.hasError || !snapshot.hasData) {
//                     return Center(
//                         child: Text(
//                             'Erreur: ${snapshot.error ?? "Aucun post trouvé"}'));
//                   }

//                   final allPosts = snapshot.data!;
//                   final referralPosts = allPosts
//                       .where((postData) =>
//                           (postData['post'] as Post).type == 'referral')
//                       .toList();

//                   if (referralPosts.isEmpty) {
//                     return const Padding(
//                       padding: EdgeInsets.all(16.0),
//                       child: Text(
//                         'Aucune offre de parrainage publiée pour le moment',
//                         style: TextStyle(
//                           color: Colors.grey,
//                           fontSize: 16,
//                         ),
//                       ),
//                     );
//                   }

//                   return ListView.builder(
//                     physics: const NeverScrollableScrollPhysics(),
//                     shrinkWrap: true,
//                     padding: const EdgeInsets.all(10),
//                     itemCount: referralPosts.length,
//                     itemBuilder: (context, index) {
//                       final postData = referralPosts[index];
//                       final post = postData['post'] as Post;
//                       final companyData =
//                           postData['company'] as Map<String, dynamic>;

//                       return PostWidget(
//                         key: ValueKey(post.id),
//                         post: post,
//                         companyCover: companyData['cover'],
//                         companyCategorie: companyData['categorie'] ?? '',
//                         companyName: companyData['name'] ?? '',
//                         companyLogo: companyData['logo'] ?? '',
//                         companyData: companyData,
//                         currentUserId: FirebaseAuth.instance.currentUser!.uid,
//                         currentProfileUserId:
//                             FirebaseAuth.instance.currentUser!.uid,
//                         onView: () {
//                           // Logique d'affichage
//                         },
//                       );
//                     },
//                   );
//                 },
//               ),
//             ],
//           ),
//         );
//       default:
//         return _buildFilteredPostList();
//     }
//   }

//   Widget _buildFilteredPostList() {
//     return FutureBuilder<List<Map<String, dynamic>>>(
//       future: _postsFuture,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasError || !snapshot.hasData) {
//           return Center(
//               child: Text('Erreur: ${snapshot.error ?? "Aucun post trouvé"}'));
//         }

//         final allPosts = snapshot.data!;
//         final filteredPosts = _currentTab == 'Toutes les publications'
//             ? allPosts
//             : allPosts
//                 .where((postData) =>
//                     (postData['post'] as Post).type ==
//                     _getPostType(_currentTab))
//                 .toList();

//         return ListView.builder(
//           physics: const NeverScrollableScrollPhysics(),
//           shrinkWrap: true,
//           padding: const EdgeInsets.all(10),
//           itemCount: filteredPosts.length,
//           itemBuilder: (context, index) {
//             final postData = filteredPosts[index];
//             final post = postData['post'] as Post;
//             final companyData = postData['company'] as Map<String, dynamic>;

//             return PostWidget(
//               key: ValueKey(post.id),
//               post: post,
//               companyCover: companyData['cover'],
//               companyCategorie: companyData['categorie'] ?? '',
//               companyName: companyData['name'] ?? '',
//               companyLogo: companyData['logo'] ?? '',
//               companyData: companyData,
//               currentUserId: FirebaseAuth.instance.currentUser!.uid,
//               currentProfileUserId: FirebaseAuth.instance.currentUser!.uid,
//               onView: () {
//                 // Logique d'affichage
//               },
//             );
//           },
//         );
//       },
//     );
//   }

//   String _getPostType(String tab) {
//     final typeMap = {
//       'Happy Deals': 'happy_deal',
//       'Évenement': 'event',
//       'Deal Express': 'express_deal',
//       "Offres d'emploi": 'job_offer',
//       'Parrainage': 'referral',
//       'Jeux concours': 'contest',
//     };
//     return typeMap[tab] ?? '';
//   }

//   Widget _buildAboutTab(Company entreprise) {
//     return ListView(
//       physics: const NeverScrollableScrollPhysics(),
//       padding: const EdgeInsets.all(16.0),
//       children: [
//         Text('Description', style: Theme.of(context).textTheme.headlineSmall),
//         const SizedBox(height: 8),
//         Text(entreprise.description),
//         const SizedBox(height: 16),
//         Text('Horaires d\'ouverture',
//             style: Theme.of(context).textTheme.headlineSmall),
//         const SizedBox(height: 8),
//         OpeningHoursWidget(openingHours: entreprise.openingHours)
//       ],
//     );
//   }

//   Widget _buildActionButtons(Company entreprise) {
//     return Consumer<CompanyLikeService>(
//       builder: (context, companyLikeService, child) {
//         final isFollowed = companyLikeService.isCompanyLiked(entreprise.id);
//         return Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 0),
//           child: Row(
//             children: [
//               Expanded(
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 300),
//                   curve: Curves.easeInOut,
//                   height: 38, // Hauteur réduite
//                   decoration: BoxDecoration(
//                     color: isFollowed ? Colors.white : const Color(0xFF0B7FE9),
//                     border: Border.all(
//                       color: isFollowed
//                           ? const Color(0xFF0B7FE9)
//                           : Colors.transparent,
//                       width: 1.2, // Bordure plus fine
//                     ),
//                     borderRadius: BorderRadius.circular(8), // Radius réduit
//                     boxShadow: [
//                       if (!isFollowed)
//                         BoxShadow(
//                           color: const Color(0xFF0B7FE9).withOpacity(0.2),
//                           blurRadius: 6,
//                           offset: const Offset(0, 3),
//                         ),
//                     ],
//                   ),
//                   child: Material(
//                     color: Colors.transparent,
//                     child: InkWell(
//                       borderRadius: BorderRadius.circular(8),
//                       onTap: () async {
//                         final updatedCompany =
//                             await companyLikeService.handleLike(entreprise);
//                         setState(() {
//                           _entrepriseFuture = Future.value(updatedCompany);
//                         });

//                         if (mounted) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text(
//                                 isFollowed
//                                     ? 'Vous ne suivez plus ${entreprise.name}'
//                                     : 'Vous suivez maintenant ${entreprise.name}',
//                                 style: const TextStyle(fontSize: 14),
//                               ),
//                               behavior: SnackBarBehavior.floating,
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               margin: const EdgeInsets.all(10),
//                               duration: const Duration(seconds: 2),
//                             ),
//                           );
//                         }
//                       },
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             isFollowed ? Icons.check_circle : Icons.add,
//                             size: 18, // Icône plus petite
//                             color: isFollowed
//                                 ? const Color(0xFF0B7FE9)
//                                 : Colors.white,
//                           ),
//                           const SizedBox(width: 6),
//                           Text(
//                             isFollowed ? 'Suivi' : 'Suivre',
//                             style: TextStyle(
//                               color: isFollowed
//                                   ? const Color(0xFF0B7FE9)
//                                   : Colors.white,
//                               fontSize: 14, // Texte plus petit
//                               fontWeight: FontWeight.w600,
//                               letterSpacing: 0.2,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 12), // Espacement réduit
//               Expanded(
//                 child: Container(
//                   height: 38, // Hauteur réduite
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
//                       begin: Alignment.centerLeft,
//                       end: Alignment.centerRight,
//                     ),
//                     borderRadius: BorderRadius.circular(8), // Radius réduit
//                     boxShadow: [
//                       BoxShadow(
//                         color: const Color(0xFF0B7FE9).withOpacity(0.2),
//                         blurRadius: 6,
//                         offset: const Offset(0, 3),
//                       ),
//                     ],
//                   ),
//                   child: Material(
//                     color: Colors.transparent,
//                     child: InkWell(
//                       borderRadius: BorderRadius.circular(8),
//                       onTap: () => _startConversation(
//                         context,
//                         entreprise,
//                         FirebaseAuth.instance.currentUser!.uid,
//                       ),
//                       child: const Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.message_outlined,
//                             size: 18, // Icône plus petite
//                             color: Colors.white,
//                           ),
//                           SizedBox(width: 6),
//                           Text(
//                             'Message',
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 14, // Texte plus petit
//                               fontWeight: FontWeight.w600,
//                               letterSpacing: 0.2,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _startConversation(
//       BuildContext context, Company company, String currentUserId) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => CompanyMessageBottomSheet(
//         company: company,
//         currentUserId: currentUserId,
//       ),
//     );
//   }
// }
