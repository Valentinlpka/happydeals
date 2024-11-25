import 'package:flutter/material.dart';
import 'package:happy/classes/news.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:intl/intl.dart';

class NewsCard extends StatelessWidget {
  final News news;
  final String companyLogo;
  final String companyName;

  const NewsCard(
      {required this.news,
      super.key,
      required this.companyLogo,
      required this.companyName});

  @override
  Widget build(BuildContext context) {
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

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section logo et nom de la compagnie
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsEntreprise(
                      entrepriseId: news.companyId,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                          2), // Épaisseur du bord en dégradé
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors
                              .white, // Fond blanc entre le bord et l'image
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: NetworkImage(companyLogo),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formatDateTime(news.timestamp),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Titre de l'actualité
            Text(
              news.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),

            // Affichage du contenu avec QuillEditor
            Text(news.content),
            const SizedBox(height: 10),

            // Liste horizontale des photos
            if (news.photos.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: news.photos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InstaImageViewer(
                        disposeLevel: DisposeLevel.low,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            news.photos[index],
                            fit: BoxFit.fitWidth,
                            width: 200,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
