import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

class DetailsEvenementPage extends StatefulWidget {
  final Event event;
  final String currentUserId;

  const DetailsEvenementPage({
    required this.event,
    super.key,
    required this.currentUserId,
  });

  @override
  // ignore: library_private_types_in_public_api
  _DetailsEvenementPageState createState() => _DetailsEvenementPageState();
}

class _DetailsEvenementPageState extends State<DetailsEvenementPage> {
  Color? appBarColor = Colors.grey[400];
  late PaletteGenerator paletteGenerator;
  late Future<Company> companyFuture;

  @override
  void initState() {
    super.initState();
    _updatePalette();
    companyFuture = _fetchCompanyDetails(widget.event.companyId);
  }

  Future<void> _updatePalette() async {
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(widget.event.photo),
    );
    setState(() {
      appBarColor = paletteGenerator.dominantColor?.color ?? Colors.grey[400];
    });
  }

  Future<Company> _fetchCompanyDetails(String companyId) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();
    return Company.fromDocument(doc);
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.event.id);

    final formattedDate =
        DateFormat('dd/MM/yyyy à HH:mm').format(widget.event.eventDate);

    return Scaffold(
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: 1,
            color: const Color.fromARGB(143, 158, 158, 158),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 30, top: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 50, vertical: 10),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                backgroundColor: const WidgetStatePropertyAll(Colors.blue),
              ),
              child: const Text(
                'Acheter un ticket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              floating: true,
              elevation: 11,
              centerTitle: true,
              title: Container(
                width: 150,
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
                        'Evènement',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              backgroundColor: appBarColor,
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
                Consumer<UserModel>(
                  builder: (context, users, _) {
                    return IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.white,
                      ),
                      onPressed: () async {
                        await users.handleLike(widget.event);
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
              pinned: true,
              expandedHeight: 250.0,
              toolbarHeight: 40,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  alignment: Alignment.topCenter,
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      SizedBox(
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Image.network(
                              widget.event.photo,
                              height: 200,
                              color: Colors.black.withOpacity(0.30),
                              colorBlendMode: BlendMode.darken,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: -75,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color.fromARGB(
                                        255,
                                        213,
                                        213,
                                        213,
                                      ),
                                    ),
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  height: 150,
                                  width: 350,
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            capitalizeFirstLetter(
                                                widget.event.title),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 22,
                                            color:
                                                Color.fromARGB(255, 95, 95, 95),
                                          ),
                                          const SizedBox(width: 10, height: 10),
                                          Text(widget.event.city),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 20,
                                            color:
                                                Color.fromARGB(255, 95, 95, 95),
                                          ),
                                          const SizedBox(width: 10, height: 10),
                                          Text(
                                              formattedDate), // Format appropriately
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.music_note,
                                            size: 22,
                                            color:
                                                Color.fromARGB(255, 95, 95, 95),
                                          ),
                                          const SizedBox(width: 10, height: 10),
                                          Text(widget.event.category),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
        body: FutureBuilder<Company>(
          future: companyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                  child: Text(
                      'Erreur de chargement des données de l\'entreprise'));
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('Entreprise introuvable'));
            }

            Company company = snapshot.data!;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A Propos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
                    Text(
                      widget.event.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
                    const Text(
                      'Organisateur',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsEntreprise(
                                entrepriseId: widget.event.companyId),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 0,
                              blurRadius: 4,
                              offset: const Offset(
                                  0, 1), // changes position of shadow
                            ),
                          ],
                          color: Colors.white,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.blue,
                              child: CircleAvatar(
                                radius: 20,
                                backgroundImage: NetworkImage(company.logo),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  company.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Row(
                                  children: [
                                    RatingBar.readOnly(
                                      filledIcon: Icons.star,
                                      size: 16,
                                      filledColor: Colors.blue,
                                      emptyIcon: Icons.star_border,
                                      initialRating: 2,
                                      maxRating: 5,
                                    ),
                                    Text(
                                      '12 avis)',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            InkWell(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Icon(Icons.message,
                                    color: Colors.white),
                              ),
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
                    const Text(
                      'Localisation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
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
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
