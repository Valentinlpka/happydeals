import 'package:flutter/material.dart';
import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/widgets/mots_cles_emploi.dart';
import 'package:palette_generator/palette_generator.dart';

class DetailsEmploiPage extends StatefulWidget {
  final JobOffer post;

  const DetailsEmploiPage({required this.post, Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _DetailsEmploiPageState createState() => _DetailsEmploiPageState();
}

class _DetailsEmploiPageState extends State<DetailsEmploiPage> {
  Color? appBarColor = Colors.grey[400];
  late PaletteGenerator paletteGenerator;

  @override
  void initState() {
    super.initState();
    _updatePalette();
  }

  Future<void> _updatePalette() async {
    const imageProvider = NetworkImage(
        'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSVHWZXfh6JF2m-fOZpEtxUEmD_gEsdUGkGYMYTUn3aeA&s');
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
                  horizontal: 100,
                  vertical: 10,
                )),
                shape: MaterialStatePropertyAll(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5))),
                backgroundColor: const MaterialStatePropertyAll(Colors.blue),
              ),
              child: const Text('Postuler',
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
                        "Offre d'emploi",
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
              expandedHeight: 200.0,
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
                              'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSVHWZXfh6JF2m-fOZpEtxUEmD_gEsdUGkGYMYTUn3aeA&s',
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
                                  height: 100,
                                  width: 330,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        widget.post.jobTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
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
                                          Text(widget.post.city)
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
                  'Mots Clés',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                Wrap(
                  runSpacing: 5,
                  spacing: 5,
                  children: widget.post.keywords
                      .map((keyword) => MotsClesEmploi(keyword))
                      .toList(),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                const Text(
                  'Entreprise',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                InkWell(
                  onTap: () {},
                  child: Container(
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
                            child:
                                const Icon(Icons.message, color: Colors.white),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                  width: 20,
                ),
                const Text(
                  'Description du poste',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                Text(
                  widget.post.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                const Text(
                  'Profil recherché',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                Text(
                  widget.post.profile,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                const Text(
                  'Pourquoi nous rejoindre ?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                Text(
                  widget.post.whyJoin,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                const Text(
                  'Vos avantages',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                Text(
                  widget.post.benefits,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
