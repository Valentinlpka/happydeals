import 'dart:math';

import 'package:accordion/accordion.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/reservation_screen.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';

class DetailsDealsExpress extends StatefulWidget {
  final ExpressDeal post;
  final String companyName;
  final String companyLogo;

  const DetailsDealsExpress(
      {super.key,
      required this.post,
      required this.companyName,
      required this.companyLogo});

  @override
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

  String generateValidationCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<DocumentReference> reserveDeal({
    required String postId,
    required int quantity,
    required int price,
    required String type,
    required DateTime pickupDate,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final validationCode = generateValidationCode();

    final postDoc =
        await FirebaseFirestore.instance.collection('posts').doc(postId).get();
    final companyId = postDoc.data()?['companyId'] as String?;
    if (companyId == null) {
      throw Exception("Company ID not found for this post");
    }

    final companyDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();
    final companyName = companyDoc.data()?['name'] as String? ?? 'Nom inconnu';

    final adresse = companyDoc.data()?['adress']['adresse'] as String? ??
        'Adresse inconnue';
    final codePostal = companyDoc.data()?['adress']['code_postal'] as String? ??
        'Code postal inconnu';
    final ville =
        companyDoc.data()?['adress']['ville'] as String? ?? 'Ville inconnue';
    final pays =
        companyDoc.data()?['adress']['pays'] as String? ?? 'Pays inconnu';
    final companyAdress = '$adresse, $codePostal, $ville, $pays';

    final reservation = {
      'buyerId': user.uid,
      'companyId': companyId,
      'companyName': companyName,
      'pickupAddress': companyAdress,
      'basketType': type,
      'postId': postId,
      'quantity': quantity,
      'price': price,
      'pickupDate': pickupDate,
      'timestamp': FieldValue.serverTimestamp(),
      'validationCode': validationCode,
      'isValidated': false,
    };

    // Mise à jour du nombre de paniers disponibles
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      if (!postSnapshot.exists) {
        throw Exception("Le post n'existe pas");
      }
      final postData = postSnapshot.data();
      if (postData == null) {
        throw Exception("Les données du post sont invalides");
      }
      final currentAvailableBaskets = postData['availableBaskets'] as int? ?? 0;
      if (currentAvailableBaskets < quantity) {
        throw Exception("Pas assez de paniers disponibles");
      }
      transaction.update(
          postRef, {'availableBaskets': currentAvailableBaskets - quantity});
    });

    return await FirebaseFirestore.instance
        .collection('reservations')
        .add(reservation);
  }

  void _showReservationSuccessDialog(String validationCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Réservation réussie'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Votre code de validation est :'),
              const SizedBox(height: 10),
              Text(
                validationCode,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Présentez ce code au commerçant lors du retrait.'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String formatDateTime(DateTime dateTime) {
    final DateTime now = DateTime.now();
    final DateFormat timeFormat = DateFormat('HH:mm');
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy');

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Aujourd'hui
      return 'aujourd\'hui à ${timeFormat.format(dateTime)}';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day + 1) {
      // Demain
      return 'demain à ${timeFormat.format(dateTime)}';
    } else {
      // Autre jour
      return 'le ${dateFormat.format(dateTime)} à ${timeFormat.format(dateTime)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.post.id);

    return Scaffold(
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(
          width: 0.4,
          color: Colors.black26,
        ))),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.blue[800]),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReservationScreen(deal: widget.post),
                  ),
                );
              },
              child: const Text('Réserver'),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            elevation: 11,
            centerTitle: true,
            titleSpacing: 50,
            title: Container(
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color.fromARGB(115, 0, 0, 0),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                  await Provider.of<UserModel>(context, listen: false)
                      .handleLike(widget.post);
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
                widget.companyLogo,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.30),
                colorBlendMode: BlendMode.darken,
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
                        Icon(
                          Icons.access_time,
                          color: Colors.blue[800],
                          size: 25,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            "à récuperer ${formatDateTime(widget.post.pickupTime)}",
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
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
                          Icons.euro_outlined,
                          color: Colors.blue[800],
                          size: 25,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Text(
                          "${widget.post.price} €",
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
              TabBar(
                labelPadding: EdgeInsets.zero,
                controller: _tabController,
                isScrollable: false,
                labelStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                dividerHeight: 0,
                unselectedLabelColor: Colors.black,
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(
                    text: 'Informations',
                  ),
                  Tab(
                    text: 'Avis',
                  ),
                ],
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
                        'Entreprise',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(
                        height: 5,
                        width: 5,
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailsEntreprise(
                                  entrepriseId: widget.post.companyId),
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
                                backgroundImage:
                                    NetworkImage(widget.companyLogo),
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
                                  capitalizeFirstLetter(widget.companyName),
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
                        width: 20,
                      ),
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
