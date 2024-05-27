import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:palette_generator/palette_generator.dart';

class DetailsEvenementPage extends StatefulWidget {
  const DetailsEvenementPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DetailsEvenementPageState createState() => _DetailsEvenementPageState();
}

class _DetailsEvenementPageState extends State<DetailsEvenementPage> {
  Color? appBarColor = Colors.grey[400];
  late PaletteGenerator paletteGenerator;

  @override
  void initState() {
    super.initState();
    _updatePalette();
  }

  Future<void> _updatePalette() async {
    const imageProvider = NetworkImage(
        'https://www.fnacspectacles.com/obj/mam/france/71/3b/calogero-tickets_185463_1669374_1240x480.jpg');
    paletteGenerator = await PaletteGenerator.fromImageProvider(imageProvider);
    setState(() {
      appBarColor = paletteGenerator.dominantColor?.color ?? Colors.grey[400];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            border: Border.all(
          width: 1,
          color: const Color.fromARGB(143, 158, 158, 158),
        )),
        padding: const EdgeInsets.only(
          bottom: 30,
          top: 15,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              style: ButtonStyle(
                padding: const MaterialStatePropertyAll(EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 10,
                )),
                shape: MaterialStatePropertyAll(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5))),
                backgroundColor: const MaterialStatePropertyAll(Colors.blue),
              ),
              child: const Text('Acheter un ticket',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
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
                width: 110,
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
                      )
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
              pinned: true,
              expandedHeight: 250.0,
              toolbarHeight: 40,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(color: Colors.white),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Image.network(
                              height: 200,
                              colorBlendMode: BlendMode.colorBurn,
                              color: Colors.black12,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              'https://www.fnacspectacles.com/obj/mam/france/71/3b/calogero-tickets_185463_1669374_1240x480.jpg',
                            ),
                            Positioned(
                              top: 150,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 20),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color.fromARGB(
                                            255, 213, 213, 213),
                                      ),
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(10),
                                      )),
                                  height: 150,
                                  width: 330,
                                  child: const Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Concert Calogéro',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              Text('dès '),
                                              Text(
                                                '29,00 €',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 22,
                                            color:
                                                Color.fromARGB(255, 95, 95, 95),
                                          ),
                                          SizedBox(width: 10, height: 10),
                                          Text('Douai')
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 20,
                                            color:
                                                Color.fromARGB(255, 95, 95, 95),
                                          ),
                                          SizedBox(width: 10, height: 10),
                                          Text('23 Avril 2024 - 19:00')
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.music_note,
                                            size: 22,
                                            color:
                                                Color.fromARGB(255, 95, 95, 95),
                                          ),
                                          SizedBox(width: 10, height: 10),
                                          Text('Concert')
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
        body: SingleChildScrollView(
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
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                const Text(
                  'Vibrez au rythme de Calogero lors de son incroyable tournée A.M.O.U.R Tour, une expérience musicale inoubliable.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                const Text(
                  'Organisateur',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset:
                            const Offset(0, 1), // changes position of shadow
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
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blue,
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(
                              'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Be Happy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
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
                                '(45 avis)',
                                style: TextStyle(fontSize: 12),
                              ),
                              // Text(DateFormat('EEEE', 'FR_fr').format(DateTime.now()))
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
                          child: const Icon(Icons.message, color: Colors.white),
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                const Text(
                  'Localisation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
