import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/rating.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:provider/provider.dart';

class RatingDialog extends StatefulWidget {
  final String adId;
  final String adTitle;
  final String toUserId;
  final String conversationId;
  final bool isSellerRating;
  final Rating? existingRating;

  const RatingDialog({
    super.key,
    required this.adId,
    required this.adTitle,
    required this.toUserId,
    required this.conversationId,
    required this.isSellerRating,
    this.existingRating,
  });

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late double _rating;
  late TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingRating?.rating ?? 0;
    _commentController =
        TextEditingController(text: widget.existingRating?.comment ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existingRating != null
                  ? 'Modifier l\'évaluation'
                  : widget.isSellerRating
                      ? "Évaluer l'acheteur"
                      : "Évaluer le vendeur",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Pour l\'article : ${widget.adTitle}'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 32,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ajouter un commentaire (optionnel)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.existingRating != null)
                  TextButton(
                    onPressed: () => _deleteRating(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Supprimer'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _rating == 0 ? null : () => _submitRating(context),
                  child: Text(
                      widget.existingRating != null ? 'Modifier' : 'Envoyer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRating(BuildContext context) async {
    if (_rating == 0) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final rating = Rating(
      id: widget.existingRating?.id ?? '',
      fromUserId: currentUser.uid,
      toUserId: widget.toUserId,
      adId: widget.adId,
      adTitle: widget.adTitle,
      rating: _rating,
      comment: _commentController.text,
      createdAt: DateTime.now(),
      conversationId: widget.conversationId,
      isSellerRating: widget.isSellerRating,
    );

    try {
      final conversationService =
          Provider.of<ConversationService>(context, listen: false);
      if (widget.existingRating != null) {
        await conversationService.updateRating(rating);
      } else {
        await conversationService.submitRating(rating);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingRating != null
              ? 'Évaluation modifiée avec succès'
              : 'Évaluation envoyée avec succès'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _deleteRating(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'évaluation'),
        content:
            const Text('Êtes-vous sûr de vouloir supprimer cette évaluation ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await Provider.of<ConversationService>(context, listen: false)
          .deleteRating(widget.existingRating!.id);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Évaluation supprimée avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
