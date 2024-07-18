import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

class DetailsParrainagePage extends StatefulWidget {
  final Referral referral;
  final String currentUserId;

  const DetailsParrainagePage({
    required this.referral,
    super.key,
    required this.currentUserId,
  });

  @override
  // ignore: library_private_types_in_public_api
  _DetailsParrainagePageState createState() => _DetailsParrainagePageState();
}

class _DetailsParrainagePageState extends State<DetailsParrainagePage> {
  Color? appBarColor = Colors.grey[400];
  late PaletteGenerator paletteGenerator;
  late Future<Company> companyFuture;

  @override
  void initState() {
    super.initState();
    _updatePalette();
    companyFuture = _fetchCompanyDetails(widget.referral.companyId);
  }

  Future<void> _updatePalette() async {
    paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(widget.referral.image),
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
        context.watch<UserModel>().likedPosts.contains(widget.referral.id);

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
                'Je parraine ! ',
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
                        'Parraiange',
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
                        await users.handleLike(widget.referral);
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
                              widget.referral.image,
                              height: 250,
                              colorBlendMode: BlendMode.colorBurn,
                              color: Colors.black12,
                              width: double.infinity,
                              fit: BoxFit.cover,
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
                                  width: 330,
                                  child: Center(
                                    child: Text(
                                      capitalizeFirstLetter(
                                          widget.referral.title),
                                      softWrap: true,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
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
                      widget.referral.description,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
                    const Text(
                      'Avantage pour le parrain',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
                    Text(
                      widget.referral.sponsorBenefit,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
                    const Text(
                      'Avantage pour le filleul',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10, width: 10),
                    Text(
                      widget.referral.refereeBenefit,
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
                                entrepriseId: widget.referral.companyId),
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
                                Row(
                                  children: [
                                    RatingBar.readOnly(
                                      filledIcon: Icons.star,
                                      size: 16,
                                      filledColor: Colors.blue,
                                      emptyIcon: Icons.star_border,
                                      initialRating: company.averageRating,
                                      maxRating: 5,
                                    ),
                                    const Text(
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
