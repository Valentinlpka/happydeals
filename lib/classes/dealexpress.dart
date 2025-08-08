import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class CompanyAddress {
  final String address;
  final String ville;
  final String codePostal;
  final String pays;
  final double latitude;
  final double longitude;

  CompanyAddress({
    required this.address,
    required this.ville,
    required this.codePostal,
    this.pays = 'France',
    required this.latitude,
    required this.longitude,
  });

  factory CompanyAddress.fromMap(Map<String, dynamic> map) {
    return CompanyAddress(
      address: map['address'] ?? '',
      ville: map['ville'] ?? '',
      codePostal: map['code_postal'] ?? '',
      pays: map['pays'] ?? 'France',
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'ville': ville,
      'code_postal': codePostal,
      'pays': pays,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class PickupAddress {
  final bool useCurrentAddress;
  final String address;
  final Map<String, double> coordinates;

  PickupAddress({
    required this.useCurrentAddress,
    required this.address,
    required this.coordinates,
  });

  factory PickupAddress.fromMap(Map<String, dynamic> map) {
    // Fonction utilitaire pour convertir en double
    double parseToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Conversion sécurisée des coordonnées
    final coordinates = map['coordinates'] as Map<String, dynamic>? ?? {};
    return PickupAddress(
      useCurrentAddress: map['useCurrentAddress'] ?? false,
      address: map['address'] ?? '',
      coordinates: {
        'lat': parseToDouble(coordinates['lat']),
        'lng': parseToDouble(coordinates['lng']),
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'useCurrentAddress': useCurrentAddress,
      'address': address,
      'coordinates': coordinates,
    };
  }
}

class PickupTimeSlot {
  final DateTime date;
  final String startTime;
  final String endTime;

  PickupTimeSlot({
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  factory PickupTimeSlot.fromMap(Map<String, dynamic> map) {
    DateTime convertToDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is Map) {
        return Timestamp(
          value['_seconds'] ?? 0,
          value['_nanoseconds'] ?? 0,
        ).toDate();
      }
      return DateTime.now();
    }

    return PickupTimeSlot(
      date: convertToDateTime(map['date']),
      startTime: map['startTime'] as String? ?? '00:00',
      endTime: map['endTime'] as String? ?? '00:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
    };
  }
}

class ExpressDeal extends Post {
  final String title;
  final String content;
  final String basketType;
  final String basketSubType;
  final String basketContent;
  final int basketCount;
  final int price;
  final int originalValue;
  final int discountPercentage;
  final int tva;
  final String imageUrl;
  final List<DateTime> pickupTimes;
  final PickupAddress pickupAddress;
  final List<String> detailsSupplementaires;
  final int maxOrdersPerSlot;
  final int totalSlots;
  final String stripeProductId;
  final String stripePriceId;
  final String stripeAccountId;
  final CompanyAddress companyAddress;
  final List<String> sharedByUsers;
  final int sharesCount;
  final bool isActive;
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  // Propriété pour récupérer les créneaux complets
  late final List<PickupTimeSlot> _pickupTimeSlots;
  List<PickupTimeSlot> get pickupTimeSlots => _pickupTimeSlots;

  ExpressDeal({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.content,
    required this.basketType,
    required this.basketSubType,
    required this.basketContent,
    required this.basketCount,
    required this.price,
    required this.originalValue,
    required this.discountPercentage,
    required this.tva,
    required this.imageUrl,
    required this.pickupTimes,
    required this.pickupAddress,
    required this.detailsSupplementaires,
    required this.maxOrdersPerSlot,
    required this.totalSlots,
    required this.stripeProductId,
    required this.stripePriceId,
    required this.stripeAccountId,
    required super.companyName,
    required super.companyLogo,
    required super.companyId,
    required this.companyAddress,
    required this.sharedByUsers,
    required this.sharesCount,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
    List<PickupTimeSlot>? pickupTimeSlots,
  }) : super(
          type: 'express_deal',
        ) {
    _pickupTimeSlots = pickupTimeSlots ?? [];
  }

  factory ExpressDeal.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Fonction utilitaire pour convertir les timestamps
    DateTime convertToDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is Map) {
        return Timestamp(
          value['_seconds'] ?? 0,
          value['_nanoseconds'] ?? 0,
        ).toDate();
      }
      return DateTime.now();
    }

    // Convertir la liste des pickupTimes avec la nouvelle structure
    List<DateTime> convertPickupTimes(List<dynamic>? times) {
      if (times == null) return [];
      
      return times.map((timeSlot) {
        if (timeSlot is Map<String, dynamic>) {
          // Nouvelle structure avec date, startTime, endTime
          final date = convertToDateTime(timeSlot['date']);
          final startTime = timeSlot['startTime'] as String? ?? '00:00';
          
          // Combiner la date avec l'heure de début
          final timeParts = startTime.split(':');
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
          
          return DateTime(
            date.year,
            date.month,
            date.day,
            hour,
            minute,
          );
        } else {
          // Ancienne structure (DateTime direct)
          return convertToDateTime(timeSlot);
        }
      }).toList();
    }

    // Convertir les créneaux complets
    List<PickupTimeSlot> convertPickupTimeSlots(List<dynamic>? times) {
      if (times == null) return [];
      
      return times.map((timeSlot) {
        if (timeSlot is Map<String, dynamic>) {
          return PickupTimeSlot.fromMap(timeSlot);
        } else {
          // Ancienne structure - créer un créneau par défaut
          final date = convertToDateTime(timeSlot);
          return PickupTimeSlot(
            date: date,
            startTime: '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
            endTime: '${(date.hour + 1).toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
          );
        }
      }).toList();
    }

    return ExpressDeal(
      id: doc.id,
      timestamp: convertToDateTime(data['timestamp']),
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      basketType: data['basketType'] ?? '',
      basketSubType: data['basketSubType'] ?? '',
      basketContent: data['basketContent'] ?? '',
      basketCount: data['basketCount'] ?? 1,
      price: data['price'] ?? 0,
      originalValue: data['originalValue'] ?? 0,
      discountPercentage: data['discountPercentage'] ?? 0,
      tva: data['tva'] ?? 0,
      imageUrl: data['imageUrl'] ?? data['images']?[0] ?? 'https://solidarites.gouv.fr/sites/solidarite/files/2024-02/panier-colis-alimentaire.jpg',
      pickupTimes: convertPickupTimes(data['pickupTimes']),
      pickupAddress: PickupAddress.fromMap(data['pickupAddress'] ?? {}),
      detailsSupplementaires: List<String>.from(data['detailsSupplementaires'] ?? []),
      maxOrdersPerSlot: data['maxOrdersPerSlot'] ?? 0,
      totalSlots: data['totalSlots'] ?? 0,
      stripeProductId: data['stripeProductId'] ?? '',
      stripePriceId: data['stripePriceId'] ?? '',
      stripeAccountId: data['stripeAccountId'] ?? '',
      companyName: data['companyName'] ?? '',
      companyLogo: data['companyLogo'] ?? '',
      companyId: data['companyId'] ?? '',
      companyAddress: CompanyAddress.fromMap(data['companyAddress'] ?? {}),
      sharedByUsers: List<String>.from(data['sharedBy'] ?? []),
      sharesCount: data['sharesCount'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null ? convertToDateTime(data['createdAt']) : null,
      updatedAt: data['updatedAt'] != null ? convertToDateTime(data['updatedAt']) : null,
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)?.map((commentData) => Comment.fromMap(commentData)).toList() ?? [],
      pickupTimeSlots: convertPickupTimeSlots(data['pickupTimes']),
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'content': content,
      'basketType': basketType,
      'basketSubType': basketSubType,
      'basketContent': basketContent,
      'basketCount': basketCount,
      'price': price,
      'originalValue': originalValue,
      'discountPercentage': discountPercentage,
      'tva': tva,
      'imageUrl': imageUrl,
      'pickupTimes': pickupTimes.map((time) => Timestamp.fromDate(time)).toList(),
      'pickupAddress': pickupAddress.toMap(),
      'detailsSupplementaires': detailsSupplementaires,
      'maxOrdersPerSlot': maxOrdersPerSlot,
      'totalSlots': totalSlots,
      'stripeProductId': stripeProductId,
      'stripePriceId': stripePriceId,
      'stripeAccountId': stripeAccountId,
      'companyName': companyName,
      'companyLogo': companyLogo,
      'companyAddress': companyAddress.toMap(),
      'sharedBy': sharedByUsers,
      'sharesCount': sharesCount,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    });
    return map;
  }

  Future<String?> reserve(String userId, DateTime selectedPickupTime) async {
    if (totalSlots > 0) {
      final reservationId = FirebaseFirestore.instance.collection('reservations').doc().id;
      final validationCode = generateValidationCode();
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final dealRef = FirebaseFirestore.instance.collection('posts').doc(id);
        final dealSnapshot = await transaction.get(dealRef);
        
        if (dealSnapshot.exists && dealSnapshot.data()!['totalSlots'] > 0) {
          transaction.update(dealRef, {'totalSlots': FieldValue.increment(-1)});
          transaction.set(
            FirebaseFirestore.instance.collection('reservations').doc(reservationId),
            {
              'dealId': id,
              'userId': userId,
              'companyId': companyId,
              'reservationTime': FieldValue.serverTimestamp(),
              'stripeAccountId': stripeAccountId,
              'validationCode': validationCode,
              'tva': tva,
              'isValidated': false,
              'selectedPickupTime': Timestamp.fromDate(selectedPickupTime),
            }
          );
          return validationCode;
        }
      });
      return validationCode;
    }
    return null;
  }

  String generateValidationCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }
}
