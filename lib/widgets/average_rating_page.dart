import 'package:flutter/material.dart';
import 'package:happy/classes/review.dart';
import 'package:happy/providers/review_service.dart';
import 'package:provider/provider.dart';

class AverageRatingWidget extends StatelessWidget {
  final String companyId;

  const AverageRatingWidget({
    super.key,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ReviewService>(
      builder: (context, reviewService, child) {
        return FutureBuilder<List<Review>>(
          future: reviewService.getReviewsForCompany(companyId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                width: 100,
                child: LinearProgressIndicator(),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Row(
                children: [
                  Row(
                    children: [
                      Icon(Icons.star_border, size: 16, color: Colors.amber),
                      Icon(Icons.star_border, size: 16, color: Colors.amber),
                      Icon(Icons.star_border, size: 16, color: Colors.amber),
                      Icon(Icons.star_border, size: 16, color: Colors.amber),
                      Icon(Icons.star_border, size: 16, color: Colors.amber),
                    ],
                  ),
                  SizedBox(width: 5),
                  Text(
                    '(0 avis)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              );
            }

            final reviews = snapshot.data!;
            final averageRating =
                reviews.fold(0.0, (sum, item) => sum + item.rating) /
                    reviews.length;

            return Row(
              children: [
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < averageRating.round()
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
                const SizedBox(width: 5),
                Text(
                  '(${reviews.length} avis)',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
