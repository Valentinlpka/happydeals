import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:gap/gap.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/widgets/opening_hours_widget.dart';
import 'package:provider/provider.dart';

import '../../providers/users.dart';

class DetailsCompany extends StatefulWidget {
  final String companyId;

  const DetailsCompany({required this.companyId, Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _DetailsCompanyState createState() => _DetailsCompanyState();
}

class _DetailsCompanyState extends State<DetailsCompany>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Company> _getCompanyData() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(widget.companyId)
        .get();
    return Company.fromDocument(doc);
  }

  @override
  Widget build(BuildContext context) {
    final bool isLiked =
        context.watch<Users>().likeList.contains(widget.companyId);
    return Scaffold(
      body: FutureBuilder<Company>(
        future: _getCompanyData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text('Erreur de chargement des données'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Entreprise introuvable'));
          }

          Company company = snapshot.data!;

          return NestedScrollView(
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  floating: true,
                  elevation: 1,
                  backgroundColor: Colors.blue[600],
                  shadowColor: Colors.grey,
                  leading: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),
                  actions: [
                    IconButton(
                      onPressed: () async {
                        if (isLiked) {
                          await context.read<Users>().unlikePost(company.id);
                        } else {
                          await context.read<Users>().likePost(company.id);
                        }
                      },
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.share,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  pinned: true,
                  expandedHeight: 620.0,
                  toolbarHeight: 40,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(color: Colors.white),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Image.network(
                                  height: 250,
                                  colorBlendMode: BlendMode.colorBurn,
                                  color: Colors.black12,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  'https://static.vecteezy.com/ti/photos-gratuite/p2/11871079-sensuelle-jeune-femme-relaxante-dans-la-piscine-spa-piscine-interieure-spa-femme-photo.jpg',
                                ),
                                Positioned(
                                  bottom: -30,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: CircleAvatar(
                                      radius: 56,
                                      backgroundColor: Colors.blue,
                                      child: CircleAvatar(
                                        radius: 52,
                                        backgroundImage:
                                            NetworkImage(company.logo),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 30.0, left: 20, right: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  company.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                  ),
                                ),
                                Text(
                                  company.categorie,
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                                const Gap(10),
                                Text(
                                  "${company.like} J'aime",
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10.0),
                                  child: Text(
                                    company.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w100,
                                    ),
                                  ),
                                ),
                                const Gap(10),
                                Row(
                                  children: [
                                    const Icon(Icons.open_in_browser_outlined),
                                    const Gap(5),
                                    Text(
                                      company.website,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined),
                                    const Gap(5),
                                    Text(company.address),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.phone),
                                    const Gap(5),
                                    Text(company.phone),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.email_outlined),
                                    const Gap(5),
                                    Text(company.email),
                                  ],
                                ),
                                const Gap(10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton(
                                      style: ButtonStyle(
                                        backgroundColor:
                                            MaterialStatePropertyAll(
                                                Colors.grey[300]),
                                        foregroundColor:
                                            const MaterialStatePropertyAll(
                                          Colors.black,
                                        ),
                                      ),
                                      onPressed: () => {},
                                      child: const Text("Suivre l'entreprise",
                                          style: TextStyle(
                                            fontSize: 14,
                                          )),
                                    ),
                                    const Gap(10),
                                    ElevatedButton(
                                      onPressed: () => {},
                                      child: const Text('Envoyer un message'),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: TabBar(
                    padding: const EdgeInsets.only(top: 0),
                    labelPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelColor: Colors.black,
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                    ),
                    tabs: const [
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10.0, vertical: 0),
                        child: Tab(text: 'Toutes les publications'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Tab(text: 'Deals'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Tab(text: 'Actions spéciales'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Tab(text: 'A propos'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: Tab(text: 'Avis'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _tabController,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(1),
                          itemBuilder: (context, index) {
                            return const Column(
                              children: [
                                Gap(10),
                              ],
                            );
                          },
                          itemCount: 5,
                        ),
                      ),
                      const Center(child: Text('Coucou')),
                      const Center(child: Text('Tab 3 Content')),
                      SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Center(
                            child: Padding(
                          padding: const EdgeInsets.only(
                              top: 10, left: 20, right: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Autres éléments
                              const SizedBox(height: 10),
                              OpeningHoursWidget(
                                  openingHours: company.openingHours),
                              // Autres éléments
                            ],
                          ),
                        )),
                      ),
                      SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Column(
                            children: [
                              Text(
                                company.rating.toString(),
                                style: const TextStyle(
                                  fontSize: 50,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              RatingBar.readOnly(
                                alignment: Alignment.center,
                                filledIcon: Icons.star,
                                size: 20,
                                filledColor: (Colors.yellow[600])!,
                                emptyIcon: Icons.star_border,
                                initialRating: company.rating,
                                maxRating: 5,
                              ),
                              const Text('basé sur X avis'),
                              ElevatedButton(
                                onPressed: () => {},
                                child: const Text('Publier un avis'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
