import 'package:flutter/material.dart';
import 'package:happy/classes/rating.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:provider/provider.dart';

Future<void> showRatingDialog({
  required BuildContext context,
  required String conversationId,
  required String fromUserId,
  required String toUserId,
  required String adId,
  required String adTitle,
  required bool isSellerRating,
}) {
  double rating = 5;
  final commentController = TextEditingController();

  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title:
                Text('Évaluer ${isSellerRating ? "l'acheteur" : "le vendeur"}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final ratingData = Rating(
                    id: '',
                    fromUserId: fromUserId,
                    toUserId: toUserId,
                    adId: adId,
                    adTitle: adTitle,
                    rating: rating,
                    comment: commentController.text,
                    createdAt: DateTime.now(),
                    conversationId: conversationId,
                    isSellerRating: isSellerRating,
                  );

                  Provider.of<ConversationService>(context, listen: false)
                      .submitRating(ratingData);

                  Navigator.pop(context);
                },
                child: const Text('Envoyer'),
              ),
            ],
          );
        },
      );
    },
  );
}
