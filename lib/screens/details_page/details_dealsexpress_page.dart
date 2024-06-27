import 'package:accordion/accordion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/providers/like_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:latlong2/latlong.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';

class DetailsDealsExpress extends StatefulWidget {
  final ExpressDeal post;
  final String currentUserId;
  final String companyName;
  final String companyLogo;

  const DetailsDealsExpress(
      {Key? key,
      required this.post,
      required this.currentUserId,
      required this.companyName,
      required this.companyLogo})
      : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _DetailsDealsExpressState createState() => _DetailsDealsExpressState();
}

class _DetailsDealsExpressState extends State<DetailsDealsExpress>
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

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<LikeProvider>().likeList.contains(widget.currentUserId);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            elevation: 11,
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
                      "Deals Express",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    )
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.blue,
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
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.white,
                ),
                onPressed: () async {
                  await Provider.of<LikeProvider>(context, listen: false)
                      .handleLike(widget.post, widget.currentUserId);
                  setState(() {}); // Force a rebuild to update the UI
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
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsCompany(
                                companyId: widget.post.companyId),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.blue[700],
                            child: CircleAvatar(
                              radius: 25,
                              backgroundImage: NetworkImage(widget.companyLogo),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                            width: 10,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.companyName,
                                style: const TextStyle(
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
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          color: Colors.blue[800],
                          size: 25,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Text(
                          widget.post.basketType,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          color: Colors.blue[700],
                          child: const Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        const Text(
                          "à récupérer aujourd'hui entre 12h00 - 18h00 ",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.blue[800],
                          size: 25,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Text(
                          widget.post.pickupTime.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.blue[800],
                          size: 25,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        const Text(
                          '59 Rue Maurice Boutton, 59135 Wallers',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.grey[300]),
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
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Que contient ce panier ?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                        width: 5,
                      ),
                      Text(
                        widget.post.content,
                        softWrap: true,
                        maxLines: null,
                      ),
                      const SizedBox(
                        height: 20,
                        width: 20,
                      ),
                      const Text(
                        'Questions fréquentes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Accordion(
                          disableScrolling: true,
                          paddingListTop: 5,
                          paddingListBottom: 5,
                          paddingListHorizontal: 0,
                          headerBackgroundColor: Colors.white,
                          rightIcon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.black),
                          flipRightIconIfOpen: true,
                          headerBorderColor: Colors.grey[300],
                          headerPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          headerBorderWidth: 1,
                          contentBorderWidth: 1,
                          headerBorderRadius: 3,
                          contentBorderColor: Colors.grey[300],
                          children: [
                            AccordionSection(
                              header:
                                  const Text('Que contient un panier surprise'),
                              content: const Text(
                                  '''Sur Happy Deals, les produits sont proposés à bas prix, mais en contrepartie… Surprise ! Les commerçants peuvent indiquer certains produits que vous pouvez retrouver dans votre panier mais sans certitude car ils ne peuvent pas prévoir leurs invendus.'''),
                            ),
                            AccordionSection(
                              header: const Text(
                                  'Mon panier peut-il contenir des produits périmés ?'),
                              content: const Text(
                                  '''Il faut distinguer la DLC et la DDM. La DLC est une date ferme, après cette date, le produit n’est plus consommable contrairement à la DDM qui elle, est une date indicative non contraignante, on peut donc vendre ces produits après la date.'''),
                            ),
                          ]),
                      const Text(
                        'Localisation',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
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
                        height: 10,
                      ),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              MapsLauncher.launchQuery('63 Rue jules mousseron'
                                  '59282'
                                  'Douchy les mines'),
                          icon:
                              const Icon(Icons.navigation, color: Colors.white),
                          label: const Text('S\'y rendre',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5), // Padding inside the button
                            textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold), // Text style
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Avis \r\n des utilisateurs ici.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
