import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Ad {
  final String id;
  String? sharedPostId;
  final String adType;
  final String title;
  final String description;
  final double price;
  final String userId;
  final String userName;
  final List<String> photos;
  final String userProfilePicture;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> additionalData;
  bool isSaved;

  // Nouvelles propriétés pour le système d'évaluation
  String? buyerId;
  bool buyerHasRated;
  bool sellerHasRated;
  DateTime? soldDate;

  bool get isSold => status == 'sold';

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
    required this.status,
    this.isSaved = false,
    this.buyerId,
    this.buyerHasRated = false,
    this.sellerHasRated = false,
    this.soldDate,
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
    bool isSaved =
        (userData['savedAds'] as List<dynamic>?)?.contains(doc.id) ?? false;

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
      status: data['status'] ?? '',
      additionalData: Map<String, dynamic>.from(data)
        ..removeWhere((key, value) => [
              'adType',
              'title',
              'description',
              'price',
              'userId',
              'photos',
              'createdAt',
              'status',
              'buyerId',
              'buyerHasRated',
              'sellerHasRated',
              'soldDate'
            ].contains(key)),
      isSaved: isSaved,
      buyerId: data['buyerId'],
      buyerHasRated: data['buyerHasRated'] ?? false,
      sellerHasRated: data['sellerHasRated'] ?? false,
      soldDate: data['soldDate'] != null
          ? (data['soldDate'] as Timestamp).toDate()
          : null,
    );
  }

  static Ad fromMap(Map<String, dynamic> map, String id) {
    return Ad(
      id: id,
      adType: map['adType'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      userProfilePicture: map['userProfilePicture'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? '',
      additionalData: Map<String, dynamic>.from(map)
        ..removeWhere((key, value) => [
              'adType',
              'title',
              'description',
              'price',
              'userId',
              'photos',
              'createdAt',
              'status',
              'buyerId',
              'buyerHasRated',
              'sellerHasRated',
              'soldDate'
            ].contains(key)),
      isSaved: map['isSaved'] ?? false,
      buyerId: map['buyerId'],
      buyerHasRated: map['buyerHasRated'] ?? false,
      sellerHasRated: map['sellerHasRated'] ?? false,
      soldDate: map['soldDate'] != null
          ? (map['soldDate'] as Timestamp).toDate()
          : null,
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
