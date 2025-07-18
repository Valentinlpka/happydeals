import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import 'package:happy/classes/post.dart';

class ServicePromotion extends Post {
  final String title;
  final String description;
  final String photo;
  final String serviceId;
  final String serviceName;
  final double oldPrice;
  final double newPrice;
  final double discountValue;
  final double discountPercentage;
  final String discountType;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> companyAddress;
  final bool isActive;
  final String searchText;

  ServicePromotion({
    required super.id,
    required super.companyId,
    required this.title,
    required this.description,
    required this.photo,
    required this.serviceId,
    required this.serviceName,
    required this.oldPrice,
    required this.newPrice,
    required this.discountValue,
    required this.discountPercentage,
    required this.discountType,
    required this.startDate,
    required this.endDate,
    required super.companyName,
    required super.companyLogo,
    required this.companyAddress,
    required this.isActive,
    required super.timestamp,
    this.searchText = '',
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    List<Map<String, dynamic>> comments = const [],
  }) : super(
          type: 'service_promotion',
          comments: comments.map((c) => Comment.fromMap(c)).toList(),
        );

  bool isValid() {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  factory ServicePromotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Fonction utilitaire pour convertir en double de manière sécurisée
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        final normalized = value.trim().replaceAll(',', '.');
        return double.tryParse(normalized) ?? 0.0;
      }
      return 0.0;
    }

    // Conversion sécurisée des prix et valeurs de réduction
    final oldPrice = parseDouble(data['oldPrice']);
    final newPrice = parseDouble(data['newPrice']);
    final discountValue = parseDouble(data['discountValue']);
    final discountPercentage = parseDouble(data['discountPercentage']);

    // Conversion sécurisée des dates
    DateTime startDate;
    try {
      startDate = (data['startDate'] as Timestamp).toDate();
    } catch (e) {
      startDate = DateTime.now();
      debugPrint('❌ Erreur de conversion de startDate: $e');
    }

    DateTime endDate;
    try {
      endDate = (data['endDate'] as Timestamp).toDate();
    } catch (e) {
      endDate = DateTime.now().add(const Duration(days: 7));
      debugPrint('❌ Erreur de conversion de endDate: $e');
    }

    // Conversion sécurisée de l'adresse
    final companyAddress = Map<String, dynamic>.from(data['companyAddress'] ?? {});
    if (companyAddress['latitude'] != null) {
      companyAddress['latitude'] = parseDouble(companyAddress['latitude']);
    }
    if (companyAddress['longitude'] != null) {
      companyAddress['longitude'] = parseDouble(companyAddress['longitude']);
    }

    // Validation et nettoyage des URLs
    String sanitizeUrl(String? url) {
      if (url == null || url.trim().isEmpty) return '';
      final trimmed = url.trim();
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        return '';
      }
      return trimmed;
    }

    return ServicePromotion(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      photo: sanitizeUrl(data['photo']),
      serviceId: data['serviceId'] ?? '',
      serviceName: data['serviceName'] ?? '',
      oldPrice: oldPrice,
      newPrice: newPrice,
      discountValue: discountValue,
      discountPercentage: discountPercentage,
      discountType: data['discountType'] ?? 'fixed',
      startDate: startDate,
      endDate: endDate,
      companyName: data['companyName'] ?? '',
      companyLogo: sanitizeUrl(data['companyLogo']),
      companyAddress: companyAddress,
      isActive: data['isActive'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: List<Map<String, dynamic>>.from(data['comments'] ?? []),
      searchText: data['searchText'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'title': title,
      'description': description,
      'photo': photo,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'oldPrice': oldPrice,
      'newPrice': newPrice,
      'discountValue': discountValue,
      'discountPercentage': discountPercentage,
      'discountType': discountType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'companyName': companyName,
      'companyLogo': companyLogo,
      'companyAddress': companyAddress,
      'isActive': isActive,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'views': views,
      'likes': likes,
      'likedBy': likedBy,
      'commentsCount': commentsCount,
      'comments': comments.map((c) => c.toMap()).toList(),
      'searchText': searchText,
    };
  }
} 