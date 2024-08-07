import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/review.dart';
import 'package:happy/providers/review_service.dart';
import 'package:happy/providers/users.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReviewListWidget extends StatelessWidget {
  final String companyId;

  const ReviewListWidget({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final reviewService = Provider.of<ReviewService>(context);

    return FutureBuilder<List<Review>>(
      future: reviewService.getReviewsForCompany(companyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        final reviews = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (reviews.isNotEmpty) _buildAverageRating(reviews),
                  TextButton(
                    onPressed: () => _showAddReviewDialog(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Mettre un avis'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(0),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                itemBuilder: (context, index) =>
                    _buildReviewItem(reviews[index]),
              ),
            ),
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

  Widget _buildReviewItem(Review review) {
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
                  CircleAvatar(
                    backgroundImage: review.userPhotoUrl.isNotEmpty
                        ? NetworkImage(review.userPhotoUrl)
                        : null,
                    child: review.userPhotoUrl.isEmpty
                        ? Text(review.userName.isNotEmpty
                            ? review.userName[0].toUpperCase()
                            : '?')
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.userName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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
                  Text(DateFormat('dd/MM/yyyy').format(review.createdAt)),
                ],
              ),
              const SizedBox(height: 8),
              Text(review.comment),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddReviewDialog(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) => AddReviewDialog(companyId: companyId),
    );
  }
}

class AddReviewDialog extends StatefulWidget {
  final String companyId;

  const AddReviewDialog({super.key, required this.companyId});

  @override
  _AddReviewDialogState createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  double _rating = 0;
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.only(
          bottom: 20,
          left: 25,
          right: 25,
          top: 25,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mettre un avis',
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
                      backgroundColor:
                          WidgetStatePropertyAll(Colors.blue[800])),
                  onPressed: () => _submitReview(context),
                  child: const Text('Ajouter mon avis'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Vous devez être connecté pour laisser un avis')),
      );
      return;
    }

    if (_rating == 0 || _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    final userModel = Provider.of<UserModel>(context, listen: false);
    await userModel
        .loadUserData(); // Assurez-vous que les données utilisateur sont à jour

    final reviewService = Provider.of<ReviewService>(context, listen: false);
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
    Navigator.of(context).pop();
  }
}
