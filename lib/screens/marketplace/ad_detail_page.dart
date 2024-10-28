import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/screens/profile.dart';
import 'package:provider/provider.dart';

class AdDetailPage extends StatelessWidget {
  final Ad ad;
  const AdDetailPage({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final conversationService = Provider.of<ConversationService>(context);

    return Scaffold(
      appBar: AppBar(title: Text(ad.title)),
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
                  Text(ad.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 23)),
                  const SizedBox(height: 8),
                  Text('${ad.price.toStringAsFixed(2)} €',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),

                  Text(
                    ad.formattedDate,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (currentUser != null && currentUser.uid != ad.userId)
                    ElevatedButton(
                      onPressed: () async {
                        final conversationId = await conversationService
                            .getOrCreateConversationForAd(
                                currentUser.uid, ad.userId, ad.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConversationDetailScreen(
                              conversationId: conversationId,
                              otherUserName: ad.userName,
                              ad: ad, // Passer l'annonce à l'écran de conversation
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

                  Text(ad.description),
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
                                    Profile(userId: ad.userId)));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                width: 1,
                                color:
                                    const Color.fromARGB(235, 189, 189, 189))),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage:
                                    NetworkImage(ad.userProfilePicture),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Text(
                                ad.userName,
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
    if (ad.photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(color: Colors.grey), // Placeholder si pas de photo
      );
    } else if (ad.photos.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          ad.photos[0],
          fit: BoxFit.contain,
        ),
      );
    } else {
      return CarouselSlider(
        options: CarouselOptions(
          aspectRatio: 16 / 9,
          viewportFraction: 1.0,
          enlargeCenterPage: false,
          enableInfiniteScroll: false,
        ),
        items: ad.photos.map((photoUrl) {
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
      );
    }
  }
}
