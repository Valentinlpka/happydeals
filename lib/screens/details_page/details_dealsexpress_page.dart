import 'package:flutter/material.dart';
import 'package:happy/classes/dealexpress.dart';

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
                onPressed: () async {},
                icon: const Icon(
                  Icons.favorite,
                  color: Colors.red,
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
                      onTap: () {},
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
                        Text(
                          "à récupérer aujourd'hui entre 12h00 - 18h00 ",
                          style: const TextStyle(
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
              children: const [
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Informations détaillées ici.'),
                ),
                SingleChildScrollView(
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
