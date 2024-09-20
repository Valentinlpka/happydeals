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
import 'package:happy/classes/loyalty_card.dart';
import 'package:happy/classes/loyalty_program.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/company_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/review_service.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/screens/shop/product_list.dart';
import 'package:happy/widgets/opening_hours_widget.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/review_list.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailsEntreprise extends StatefulWidget {
  final String entrepriseId;

  const DetailsEntreprise({super.key, required this.entrepriseId});

  @override
  _DetailsEntrepriseState createState() => _DetailsEntrepriseState();
}

class _DetailsEntrepriseState extends State<DetailsEntreprise> {
  late Future<LoyaltyProgram?> _loyaltyProgramFuture;

  late Future<LoyaltyCard?> _loyaltyCardFuture;

  late Future<Company> _entrepriseFuture;

  late Future<List<Map<String, dynamic>>> _postsFuture;

  String _currentTab = 'Toutes les publications';

  final List<String> _tabs = [
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
  ];

  @override
  void initState() {
    super.initState();
    _entrepriseFuture = _fetchEntrepriseData();
    _postsFuture = _fetchAllPosts();
    _loyaltyProgramFuture = _fetchLoyaltyProgram();
    _loyaltyCardFuture = _fetchLoyaltyCard();
  }

  Future<LoyaltyProgram?> _fetchLoyaltyProgram() async {
    final doc = await FirebaseFirestore.instance
        .collection('LoyaltyPrograms')
        .where('companyId', isEqualTo: widget.entrepriseId)
        .get();
    if (doc.docs.isNotEmpty) {
      return LoyaltyProgram.fromFirestore(doc.docs.first);
    }
    return null;
  }

  Future<LoyaltyCard?> _fetchLoyaltyCard() async {
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
  }

  Future<Company> _fetchEntrepriseData() async {
    final doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(widget.entrepriseId)
        .get();
    return Company.fromDocument(doc);
  }

  Future<List<Map<String, dynamic>>> _fetchAllPosts() async {
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
      return null;
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
      expandedHeight: 150.0,
      automaticallyImplyLeading: true,
      leading: IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new_outlined, color: Colors.white),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: CachedNetworkImage(
          imageUrl: entreprise.cover,
          fit: BoxFit.cover,
          colorBlendMode: BlendMode.darken,
          color: Colors.black.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs.map((tab) => _buildTab(tab)).toList(),
      ),
    );
  }

  Widget _buildTab(String tabName) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 10.0,
        right: 10,
        top: 10,
      ),
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
                  backgroundImage: CachedNetworkImageProvider(entreprise.logo),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (entreprise.name),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    Text((entreprise.categorie)),
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
                    ),
                    const SizedBox(height: 16),
                    Text(_buildProgramDescription(program)),
                    const SizedBox(height: 16),
                    if (cardSnapshot.hasData && cardSnapshot.data != null)
                      Text(
                          "Votre progression : ${cardSnapshot.data!.currentValue} / ${program.targetValue}"),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      child: Text(
                          cardSnapshot.hasData && cardSnapshot.data != null
                              ? "Voir ma carte"
                              : "S'inscrire"),
                      onPressed: () =>
                          cardSnapshot.hasData && cardSnapshot.data != null
                              ? _showLoyaltyCard(cardSnapshot.data!)
                              : _subscribeLoyaltyProgram(program),
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
    // Afficher les détails de la carte de fidélité
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Ma carte de fidélité"),
          content: Text("Progression actuelle : ${card.currentValue}"),
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

  void _subscribeLoyaltyProgram(LoyaltyProgram program) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    // Créer une nouvelle carte de fidélité
    final newCard = LoyaltyCard(
      id: '', // Sera généré par Firestore
      customerId: userId,
      loyaltyProgramId: program.id,
      companyId: widget.entrepriseId,
      currentValue: 0,
    );

    try {
      // Ajouter la carte à Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('LoyaltyCards')
          .add(newCard.toFirestore());

      // Mettre à jour l'état local
      setState(() {
        _loyaltyCardFuture = Future.value(newCard.copyWith(id: docRef.id));
      });

      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Inscription au programme de fidélité réussie!')),
      );

      // Fermer le bottom sheet
      Navigator.of(context).pop();
    } catch (e) {
      // Gérer les erreurs
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Erreur lors de l\'inscription au programme de fidélité')),
      );
    }
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
            launchUrl(Uri.parse(url));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Impossible d\'ouvrir $url')),
            );
          }
        },
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey)),
            ),
          ],
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
      default:
        return _buildFilteredPostList();
    }
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
              child: Text('Erreur: ${snapshot.error ?? "Aucun post trouvé"}'));
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
              onView: () {
                // Logique d'affichage
              },
            );
          },
        );
      },
    );
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
        OpeningHoursWidget(openingHours: entreprise.openingHours)
      ],
    );
  }

  Widget _buildActionButtons(Company entreprise) {
    return Consumer<CompanyLikeService>(
      builder: (context, companyLikeService, child) {
        final isLiked = companyLikeService.isCompanyLiked(entreprise.id);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: isLiked ? 0 : 2,
                      color: isLiked
                          ? Colors.blue
                          : const Color.fromARGB(255, 21, 108, 179),
                    ),
                    gradient: isLiked
                        ? const LinearGradient(
                            colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                            stops: [0.0, 1.0],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 251, 251, 251),
                              Color.fromARGB(255, 255, 255, 255)
                            ],
                            stops: [0.0, 1.0],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(
                        color: isLiked ? Colors.white : Colors.black,
                      ),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: () async {
                      final updatedCompany =
                          await companyLikeService.handleLike(entreprise);
                      setState(() {
                        _entrepriseFuture = Future.value(updatedCompany);
                      });
                    },
                    child: Text(
                      isLiked ? 'Aimé' : 'Aimer l\'entreprise',
                      style: TextStyle(
                        color: isLiked ? Colors.white : Colors.black,
                      ),
                    ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: () => _startConversation(context, entreprise,
                        FirebaseAuth.instance.currentUser!.uid),
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
}
