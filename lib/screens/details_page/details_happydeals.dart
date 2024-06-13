import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/deal_product.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class DetailsHappyDeals extends StatefulWidget {
  final HappyDeal happydeal;

  final String currentUserId;

  const DetailsHappyDeals({
    Key? key,
    required this.happydeal,
    required this.currentUserId,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _DetailsHappyDealsState createState() => _DetailsHappyDealsState();
}

class _DetailsHappyDealsState extends State<DetailsHappyDeals>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/mm/yyyy')
        .format(dateTime); // Format comme "2024-06-13"
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<Users>().likeList.contains(widget.happydeal.id);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            elevation: 0,
            centerTitle: true,
            title: Container(
              width: 130,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color.fromARGB(115, 0, 0, 0),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    Text(
                      "Happy Deals",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.blue[700],
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
              Consumer<Users>(
                builder: (context, users, _) {
                  return IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                    ),
                    onPressed: () async {
                      await users.handleLike(widget.happydeal);
                      setState(() {}); // Force a rebuild to update the UI
                    },
                  );
                },
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.share,
                  color: Colors.white,
                ),
              ),
            ],
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                'https://previews.123rf.com/images/kzenon/kzenon1411/kzenon141101650/33752503-deux-femmes-dans-le-bien-%C3%AAtre-spa-de-d%C3%A9tente-dans-le-sauna-en-bois.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            floating: false,
            delegate: _SliverHeaderDelegate(
              minHeight: 30,
              maxHeight: 30,
              child: Container(
                color: Colors.blue[700],
                child: const Center(
                  child: Text(
                    'Ce deal expire dans 2 jours !',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {},
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.blue[700],
                            child: const CircleAvatar(
                              radius: 25,
                              backgroundImage: NetworkImage(
                                  'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                            width: 10,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Be Happy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    color: Colors.blue[700],
                                    child: const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                    width: 10,
                                  ),
                                  const Text(
                                    '4,4',
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                    width: 5,
                                  ),
                                  // Your rating widget here
                                  const Text(
                                    '(45 avis)',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 35,
                color: Colors.transparent,
                child: TabBar(
                  labelPadding: EdgeInsets.zero,
                  controller: _tabController,
                  isScrollable: false,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.0,
                      ),
                      child: Tab(
                        text: 'Informations',
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.0,
                      ),
                      child: Tab(
                        text: 'Avis',
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.happydeal.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(widget.happydeal.description),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Choix du deal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      Column(
                        children: widget.happydeal.deals.map(
                          (deal) {
                            return Column(
                              children: [
                                DealProduct(
                                    name: deal.name,
                                    oldPrice: deal.oldPrice,
                                    newPrice: deal.newPrice,
                                    discount: deal.discount),
                                const SizedBox(
                                  height: 10,
                                )
                              ],
                            );
                          },
                        ).toList(),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Validité du deal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      Text(
                        '${formatDateTime(widget.happydeal.startDate)} - ${formatDateTime(widget.happydeal.endDate)} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Comment en profiter ?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Blabla blabla blabla',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Comment nous contacter ?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        "Partie contact de l'annuaire",
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        'Localisation ?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      const Text(
                        '59 Rue Maurice Boutton, 59135, Wallers, France',
                      ),
                      const SizedBox(
                        height: 10,
                        width: 10,
                      ),
                      SizedBox(
                        height: 200,
                        child: FlutterMap(
                          mapController: MapController(),
                          options: const MapOptions(
                            initialCenter:
                                LatLng(50.37714385986328, 3.4123148918151855),
                            initialZoom: 14,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              // Plenty of other options available!
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: const LatLng(
                                      50.37714385986328, 3.4123148918151855),
                                  width: 100,
                                  height: 100,
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.red[800],
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                        width: 10,
                      ),
                    ],
                  ),
                ),
                const SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Avis des utilisateurs ici.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _SliverHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate.maxExtent != maxExtent ||
        oldDelegate.minExtent != minExtent ||
        (oldDelegate as _SliverHeaderDelegate).child != child;
  }
}
