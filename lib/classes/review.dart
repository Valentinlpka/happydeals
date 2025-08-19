import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String comment;
  final String companyId;
  final DateTime createdAt;
  final int rating;
  final String userId;
  final String userName;
  final String userPhotoUrl;

  Review({
    required this.id,
    required this.comment,
    required this.companyId,
    required this.createdAt,
    required this.rating,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Review(
      id: doc.id,
      comment: data['comment']?.toString() ?? '',
      companyId: data['companyId']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      rating: data['rating'] ?? 0,
      userId: data['userId']?.toString() ?? '',
      userName: data['userName']?.toString() ?? 'Utilisateur anonyme',
      userPhotoUrl: data['userPhotoUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'comment': comment,
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'rating': rating,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
    };
  }

  // Méthode helper pour formater la date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  // Méthode helper pour obtenir les étoiles
  List<bool> get stars {
    return List.generate(5, (index) => index < rating);
  }
}