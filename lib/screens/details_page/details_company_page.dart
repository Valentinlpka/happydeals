import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/services/product_service.dart';
import 'package:happy/widgets/cards/product_card.dart';
import 'package:happy/widgets/opening_hours_widget.dart';
import 'package:provider/provider.dart';

import '../../providers/users.dart';

class DetailsCompany extends StatefulWidget {
  final String companyId;

  const DetailsCompany({required this.companyId, super.key});

  @override
  _DetailsCompanyState createState() => _DetailsCompanyState();
}

class _DetailsCompanyState extends State<DetailsCompany>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<Map<String, dynamic>> _companyDataFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _companyDataFuture = _getCompanyDataAndProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getCompanyDataAndProducts() async {
    final companyDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(widget.companyId)
        .get();
    final company = Company.fromDocument(companyDoc);

    final productsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('sellerId', isEqualTo: company.sellerId)
        .get();

    final products = productsSnapshot.docs
        .map((doc) => Product.fromMap(doc.data(), doc.id))
        .toList();

    return {
      'company': company,
      'products': products,
    };
  }

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModel>(context);
    final bool isLiked = userModel.likedPosts.contains(widget.companyId);
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _companyDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Données introuvables'));
          }

          final company = snapshot.data!['company'] as Company;
          final products = snapshot.data!['products'] as List<Product>;

          return NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  floating: true,
                  pinned: true,
                  expandedHeight: 620.0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildCompanyHeader(
                        company, isLiked, userModel, currentUserId),
                  ),
                  bottom: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Toutes les publications'),
                      Tab(text: 'Deals'),
                      Tab(text: 'Actions spéciales'),
                      Tab(text: 'A propos'),
                      Tab(text: 'Avis'),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPublicationsTab(),
                _buildDealsTab(),
                _buildProductsTab(products, company.sellerId),
                _buildAboutTab(company),
                _buildReviewsTab(company),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompanyHeader(Company company, bool isLiked, UserModel userModel,
      String currentUserId) {
    return Column(
      children: [
        _buildHeaderImage(company),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(company.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 28)),
              Text(company.categorie, style: const TextStyle(fontSize: 16)),
              const Gap(10),
              Text("${company.like} J'aime"),
              Text(company.description,
                  style: const TextStyle(fontWeight: FontWeight.w300)),
              const Gap(10),
              _buildCompanyInfo(company),
              const Gap(10),
              _buildActionButtons(company, isLiked, userModel, currentUserId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderImage(Company company) {
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Image.network(
            'https://example.com/header_image.jpg',
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: -30,
            left: 20,
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.blue,
              child: CircleAvatar(
                radius: 52,
                backgroundImage: NetworkImage(company.logo),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfo(Company company) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(Icons.open_in_browser_outlined, company.website),
        _buildInfoRow(Icons.location_on_outlined, company.address),
        _buildInfoRow(Icons.phone, company.phone),
        _buildInfoRow(Icons.email_outlined, company.email),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon),
        const Gap(5),
        Text(text),
      ],
    );
  }

  Widget _buildActionButtons(Company company, bool isLiked, UserModel userModel,
      String currentUserId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300], foregroundColor: Colors.black),
          onPressed: () {},
          child:
              const Text("Suivre l'entreprise", style: TextStyle(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () => _startConversation(context, company, currentUserId),
          child: const Text('Envoyer un message'),
        ),
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

  Widget _buildPublicationsTab() {
    return const Center(child: Text('Toutes les publications'));
  }

  Widget _buildDealsTab() {
    return const Center(child: Text('Deals'));
  }

  Widget _buildProductsTab(List<Product> products, String sellerId) {
    print(sellerId);
    final ProductService productService = ProductService();
    return FutureBuilder<List<Product>>(
      future: productService.getProductsForSeller(sellerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          print(snapshot.data);
          return const Center(child: Text('Aucun produit trouvé'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            Product product = snapshot.data![index];
            return ProductCard(product: product);
          },
        );
      },
    );
  }

  Widget _buildAboutTab(Company company) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Horaires d\'ouverture',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(10),
            OpeningHoursWidget(openingHours: company.openingHours),
            const Gap(20),
            const Text('À propos de nous',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Gap(10),
            Text(company.description),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsTab(Company company) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              company.rating.toString(),
              style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold),
            ),
            RatingBar.readOnly(
              filledIcon: Icons.star,
              emptyIcon: Icons.star_border,
              initialRating: company.rating,
              maxRating: 5,
              size: 20,
              filledColor: Colors.yellow,
            ),
            const Text('basé sur X avis'),
            ElevatedButton(
              onPressed: () {
                // Ajoutez ici la logique pour publier un avis
              },
              child: const Text('Publier un avis'),
            ),
            // Ajoutez ici une liste des avis existants
          ],
        ),
      ),
    );
  }
}
