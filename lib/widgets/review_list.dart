import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/review.dart';
import 'package:happy/providers/review_service.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/profile.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReviewListWidget extends StatefulWidget {
  final String companyId;

  const ReviewListWidget({super.key, required this.companyId});

  @override
  State<ReviewListWidget> createState() => _ReviewListWidgetState();
}

class _ReviewListWidgetState extends State<ReviewListWidget>
    with AutomaticKeepAliveClientMixin {
  // Ajout de cette propriété pour garder l'état
  @override
  bool get wantKeepAlive => true;

  // Cache pour les reviews
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    final reviewService = Provider.of<ReviewService>(context, listen: false);
    _reviewsFuture = reviewService.getReviewsForCompany(widget.companyId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Nécessaire pour AutomaticKeepAliveClientMixin

    return FutureBuilder<List<Review>>(
      future: _reviewsFuture, // Utilisation du cache
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final reviews = snapshot.data ?? [];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final hasUserReviewed = currentUserId != null &&
            reviews.any((review) => review.userId == currentUserId);

        return ListView(
          children: [
            // Section moyenne et bouton d'ajout
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reviews.isNotEmpty) _buildAverageRating(reviews),
                  if (!hasUserReviewed && currentUserId != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(26 * 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[800],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Partagez votre expérience',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pour laisser un avis, vous devez avoir effectué un achat chez ce professionnel',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () =>
                                      _showAddReviewDialog(context),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.blue[800],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Mettre un avis'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Message si aucun avis
            if (reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Aucun avis pour le moment',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

            // Liste des avis
            ...reviews.map((review) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _buildReviewItem(review, context),
                )),

            // Espace en bas pour éviter que le dernier avis soit caché
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildAverageRating(List<Review> reviews) {
    double averageRating =
        reviews.fold(0.0, (sum, item) => sum + item.rating) / reviews.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          textAlign: TextAlign.center,
          averageRating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (index) => Icon(
                        index < averageRating.round()
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber))),
            const SizedBox(height: 5),

            Text('${reviews.length} avis'),
            // Ici, vous pouvez ajouter la répartition des notes si nécessaire
          ],
        ),
      ],
    );
  }

  Widget _buildReviewItem(Review review, context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUserReview = currentUserId == review.userId;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        borderOnForeground: true,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Profile(userId: review.userId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      backgroundImage: review.userPhotoUrl.isNotEmpty
                          ? NetworkImage(review.userPhotoUrl)
                          : null,
                      child: review.userPhotoUrl.isEmpty
                          ? Text(review.userName.isNotEmpty
                              ? review.userName[0].toUpperCase()
                              : '?')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                Profile(userId: review.userId),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < review.rating
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 16,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(DateFormat('dd/MM/yyyy').format(review.createdAt)),
                      if (isCurrentUserReview) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () =>
                              _showEditReviewDialog(context, review),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.red),
                          onPressed: () =>
                              _showDeleteConfirmation(context, review),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(review.comment),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditReviewDialog(BuildContext context, Review review) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => AddReviewDialog(
        companyId: review.companyId,
        existingReview: review,
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'avis'),
        content: const Text('Êtes-vous sûr de vouloir supprimer votre avis ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final reviewService =
                  Provider.of<ReviewService>(context, listen: false);
              await reviewService.deleteReview(review.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showAddReviewDialog(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => AddReviewDialog(companyId: widget.companyId),
    );
  }
}

class AddReviewDialog extends StatefulWidget {
  final String companyId;
  final Review? existingReview;

  const AddReviewDialog({
    super.key,
    required this.companyId,
    this.existingReview,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  double _rating = 0;
  late TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingReview?.rating ?? 0;
    _commentController =
        TextEditingController(text: widget.existingReview?.comment ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(25),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingReview != null
                        ? 'Modifier l\'avis'
                        : 'Mettre un avis',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Quelle est votre note ?'),
              Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () => setState(() => _rating = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text('Veuillez ajouter un commentaire'),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.blue[800]),
                  ),
                  onPressed: () => _submitReview(context),
                  child: Text(widget.existingReview != null
                      ? 'Modifier'
                      : 'Ajouter mon avis'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitReview(BuildContext context) async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user == null) {
      _showErrorDialog(
          context, 'Vous devez être connecté pour laisser un avis');
      return;
    }

    if (_rating == 0 || _commentController.text.isEmpty) {
      _showErrorDialog(context, 'Veuillez remplir tous les champs');
      return;
    }

    final userModel = Provider.of<UserModel>(context, listen: false);
    await userModel.loadUserData();

    if (!context.mounted) return;

    final reviewService = Provider.of<ReviewService>(context, listen: false);
    try {
      if (widget.existingReview != null) {
        await reviewService.updateReview(
          widget.existingReview!.id,
          rating: _rating,
          comment: _commentController.text,
        );
      } else {
        final review = Review(
          id: '',
          userId: user.uid,
          companyId: widget.companyId,
          rating: _rating,
          comment: _commentController.text,
          createdAt: DateTime.now(),
          userName: '${userModel.firstName} ${userModel.lastName}',
          userPhotoUrl: userModel.profileUrl,
        );
        await reviewService.addReview(review);
      }
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showErrorDialog(context, e.toString());
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 28),
              const SizedBox(width: 10),
              const Text(
                'Erreur',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 24,
        );
      },
    );
  }
}
