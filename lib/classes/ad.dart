import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Ad {
  final String id;
  final String adType;
  final String title;
  final String description;
  final double price;
  final String userId;
  final String userName;
  final List<String> photos;
  final String userProfilePicture;
  final DateTime createdAt;
  final Map<String, dynamic> additionalData;

  Ad({
    required this.id,
    required this.adType,
    required this.title,
    required this.description,
    required this.price,
    required this.userId,
    required this.photos,
    required this.userName,
    required this.userProfilePicture,
    required this.createdAt,
    required this.additionalData,
  });

  String get formattedDate => formatDate(createdAt);

  static Future<Ad> fromFirestore(DocumentSnapshot doc) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // Récupérer les informations de l'utilisateur
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(data['userId'])
        .get();

    Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
    String userName =
        '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
    String userProfilePicture = userData['image_profile'] ?? '';

    return Ad(
      id: doc.id,
      adType: data['adType'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      userId: data['userId'] ?? '',
      userName: userName.trim(),
      photos: List<String>.from(data['photos'] ?? []),
      userProfilePicture: userProfilePicture,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      additionalData: Map<String, dynamic>.from(data)
        ..removeWhere((key, value) => [
              'adType',
              'title',
              'description',
              'price',
              'userId',
              'photos',
              'createdAt'
            ].contains(key)),
    );
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final formatter = DateFormat('HH:mm');

    if (difference.inDays == 0) {
      return "Aujourd'hui à ${formatter.format(date)}";
    } else if (difference.inDays == 1) {
      return "Hier à ${formatter.format(date)}";
    } else if (difference.inDays < 3) {
      return "Il y a ${difference.inDays} jours à ${formatter.format(date)}";
    } else {
      return "${DateFormat('dd/MM').format(date)} à ${formatter.format(date)}";
    }
  }
}
