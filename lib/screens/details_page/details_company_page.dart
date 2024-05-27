import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/widgets/deals_express_card.dart';
import 'package:provider/provider.dart';

import '../../providers/users.dart';

class DetailsCompany extends StatefulWidget {
  final Company company;

  const DetailsCompany(this.company, {super.key});

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

  @override
  Widget build(BuildContext context) {
    final bool isLiked =
        context.watch<Users>().likeList.contains(widget.company.id);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
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
                      await context.read<Users>().unlikePost(widget.company.id);
                    } else {
                      await context.read<Users>().likePost(widget.company.id);
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
              expandedHeight: 650.0,
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
                            const Positioned(
                              bottom: -30,
                              child: Padding(
                                padding: EdgeInsets.only(left: 20),
                                child: CircleAvatar(
                                  radius: 56,
                                  backgroundColor: Colors.blue,
                                  child: CircleAvatar(
                                    radius: 52,
                                    backgroundImage: NetworkImage(
                                      'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I',
                                    ),
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
                              widget.company.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                            Text(
                              widget.company.categories,
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            const Gap(10),
                            const Text(
                              "3K J'aime",
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10.0),
                              child: Text(
                                maxLines: 5,
                                "Première société de courtage en énergie et télécoms au nord de Paris. Que vous soyez professionnel ou particulier, notre équipe de courtiers est là pour vous accompagner dans la souscription et la négociation de vos contrats.",
                                style: TextStyle(
                                  fontWeight: FontWeight.w100,
                                ),
                              ),
                            ),
                            const Gap(10),
                            const Row(
                              children: [
                                Icon(Icons.open_in_browser_outlined),
                                Gap(5),
                                Text("behappy-services.fr",
                                    style: TextStyle(
                                      color: Colors.blue,
                                    )),
                              ],
                            ),
                            const Row(
                              children: [
                                Icon(Icons.open_in_browser_outlined),
                                Gap(5),
                                Text("1 Rue Victor Delbove, 59770 Marly"),
                              ],
                            ),
                            const Row(
                              children: [
                                Icon(Icons.open_in_browser_outlined),
                                Gap(5),
                                SizedBox(width: 5, height: 5),
                                Text("06 59 97 53 90"),
                              ],
                            ),
                            const Row(
                              children: [
                                Icon(Icons.open_in_browser_outlined),
                                Gap(5),
                                Text("infos@behappy-services.fr"),
                              ],
                            ),
                            const Gap(10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton(
                                  style: ButtonStyle(
                                    backgroundColor: MaterialStatePropertyAll(
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
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                  isScrollable: true,
                  indicatorColor: Colors.blue[600],
                  labelColor: Colors.blue[600],
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelColor: Colors.black,
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Toutes les publications'),
                    Tab(text: 'Deals'),
                    Tab(text: 'Actions spéciales'),
                    Tab(text: 'Chips'),
                    Tab(text: 'Avis'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
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
                      DealsExpressCard(),
                    ],
                  );
                },
                itemCount: 5,
              ),
            ),
            const Center(child: Text('Coucou')),
            const Center(child: Text('Tab 3 Content')),
            const Center(child: Text('Tab 4 Content')),
            Column(
              children: [
                const Text(
                  '4.0',
                  style: TextStyle(
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
                  initialRating: 5,
                  maxRating: 1,
                ),
                const Text('basé sur X avis'),
                ElevatedButton(
                  onPressed: () => {},
                  child: const Text('Publier un avis'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
