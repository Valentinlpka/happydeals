import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:provider/provider.dart';

class AdDetailPage extends StatefulWidget {
  final Ad ad;
  const AdDetailPage({super.key, required this.ad});

  @override
  State<AdDetailPage> createState() => _AdDetailPageState();
}

class _AdDetailPageState extends State<AdDetailPage> {
  int current = 0; // Ajoutez cette variable dans votre state
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final conversationService = Provider.of<ConversationService>(context);

    return Scaffold(
      appBar: CustomAppBarBack(title: widget.ad.title),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhotoSection(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.ad.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 23)),
                  const SizedBox(height: 8),
                  Text('${widget.ad.price.toStringAsFixed(2)} €',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),

                  Text(
                    widget.ad.formattedDate,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (currentUser != null &&
                      currentUser.uid != widget.ad.userId)
                    ElevatedButton(
                      onPressed: () async {
                        final conversationId = await conversationService
                            .getOrCreateConversationForAd(currentUser.uid,
                                widget.ad.userId, widget.ad.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConversationDetailScreen(
                              conversationId: conversationId,
                              otherUserName: widget.ad.userName,
                              ad: widget
                                  .ad, // Passer l'annonce à l'écran de conversation
                            ),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.message),
                          SizedBox(width: 8),
                          Text('Contacter le vendeur'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  Text(widget.ad.description),
                  const SizedBox(height: 16),

                  Column(children: [
                    const Row(
                      children: [
                        Text(
                          'Information sur le vendeur : ',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    Profile(userId: widget.ad.userId)));
                      },
                      child: Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage:
                                    NetworkImage(widget.ad.userProfilePicture),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Text(
                                widget.ad.userName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),
                      ),
                    )
                  ]),
                  const SizedBox(
                    height: 10,
                  ),

                  // Ajouter d'autres détails spécifiques au type d'annonce ici
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            aspectRatio: 16 / 9,
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() {
                current = index;
              });
            },
          ),
          items: widget.ad.photos.map((photoUrl) {
            return Builder(
              builder: (BuildContext context) {
                return Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width,
                );
              },
            );
          }).toList(),
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.ad.photos.asMap().entries.map((entry) {
              return Container(
                width: 7.0, // Augmenté
                height: 7.0, // Augmenté
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current == entry.key
                      ? Colors.black
                      : Colors.white.withOpacity(0.5),
                  border: Border.all(
                      color: Colors.black.withOpacity(0.3)), // Ajouté
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
