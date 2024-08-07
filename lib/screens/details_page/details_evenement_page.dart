import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
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
  _DetailsEvenementPageState createState() => _DetailsEvenementPageState();
}

class _DetailsEvenementPageState extends State<DetailsEvenementPage> {
  late Future<Company> companyFuture;

  @override
  void initState() {
    super.initState();
    companyFuture = _fetchCompanyDetails(widget.event.companyId);
  }

  Future<Company> _fetchCompanyDetails(String companyId) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();
    return Company.fromDocument(doc);
  }

  String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy à HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.event.id);

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
                backgroundColor: WidgetStateProperty.all(Colors.blue[800]),
              ),
              onPressed: () {
                // Implement ticket purchase functionality
              },
              child: const Text('Acheter un ticket'),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    Text(
                      maxLines: 1,
                      'Evènement',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          overflow: TextOverflow.ellipsis),
                    ),
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
                      .handleLike(widget.event);
                  setState(() {});
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
                widget.event.photo,
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
                    Text(
                      capitalizeFirstLetter(widget.event.title),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(
                          widget.event.city,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(
                          formatDate(widget.event.eventDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.music_note,
                            color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(
                          widget.event.category,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.grey[300]),
            ]),
          ),
          SliverFillRemaining(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A Propos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.event.description),
                  const SizedBox(height: 20),
                  const Text(
                    'Organisateur',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<Company>(
                    future: companyFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Text(
                            'Erreur de chargement des données de l\'entreprise');
                      }

                      Company company = snapshot.data!;

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailsEntreprise(
                                  entrepriseId: widget.event.companyId),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 27,
                              backgroundColor: Colors.blue[700],
                              child: CircleAvatar(
                                radius: 25,
                                backgroundImage: NetworkImage(company.logo),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    capitalizeFirstLetter(company.name),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    ' (12 avis)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
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
                              onTap: () {
                                // Implement messaging functionality
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Localisation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: const MapOptions(
                        initialCenter:
                            LatLng(50.37714385986328, 3.4123148918151855),
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
          ),
        ],
      ),
    );
  }
}
