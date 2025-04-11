import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Company {
  final String id;
  final String name;
  final String entityType;
  final String categorie;
  final String cover;
  final String description;
  final String email;
  final int like;
  final String logo;
  final List<Map<String, dynamic>> gallery;
  final String phone;
  final String type;
  final String website;
  final String sellerId;
  final Address adress;
  final OpeningHours openingHours;
  final double? averageRating;
  final int? numberOfReviews;
  final DateTime createdAt;

  Company({
    required this.id,
    required this.name,
    required this.entityType,
    required this.categorie,
    required this.website,
    required this.cover,
    required this.gallery,
    required this.description,
    required this.email,
    required this.like,
    required this.logo,
    required this.phone,
    required this.type,
    required this.sellerId,
    required this.adress,
    DateTime? createdAt,
    required this.openingHours,
    this.averageRating,
    this.numberOfReviews,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Company.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      entityType: data['entityType'] ?? '',
      website: data['website'] ?? '',
      categorie: data['categorie'] ?? '',
      cover: data['cover'] ?? '',
      gallery: List<Map<String, dynamic>>.from(data['gallery'] ?? []),
      description: data['description'] ?? '',
      email: data['email'] ?? '',
      like: data['like'] ?? 0,
      logo: data['logo'] ?? '',
      phone: data['phone'] ?? '',
      type: data['type'] ?? '',
      sellerId: data['sellerId'] ?? '',
      adress: Address.fromMap(data['adress'] ?? {}),
      openingHours: OpeningHours(
        hours: Map<String, String>.from(data['openingHours'] ?? {}),
        sameHoursAllDays: false,
      ),
      averageRating: (data['rating'] as num?)?.toDouble(),
      numberOfReviews: data['numberOfReviews'] as int?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'entityType': entityType,
      'categorie': categorie,
      'cover': cover,
      'description': description,
      'website': website,
      'email': email,
      'like': like,
      'logo': logo,
      'gallery': gallery,
      'phone': phone,
      'type': type,
      'sellerId': sellerId,
      'adress': adress.toMap(),
      'openingHours': openingHours.toMap(),
      'averageRating': averageRating,
      'numberOfReviews': numberOfReviews,
      'createdAt': createdAt,
    };
  }
}

class Address {
  final String adresse;
  final String codePostal;
  final String pays;
  final String ville;
  final double? latitude;
  final double? longitude;

  Address({
    required this.adresse,
    required this.codePostal,
    required this.pays,
    required this.ville,
    this.longitude,
    this.latitude,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      adresse: map['adresse'] ?? '',
      codePostal: map['code_postal'] ?? '',
      pays: map['pays'] ?? '',
      ville: map['ville'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adresse': adresse,
      'code_postal': codePostal,
      'pays': pays,
      'ville': ville,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class OpeningHours {
  final Map<String, String> hours;
  final bool sameHoursAllDays;

  OpeningHours({
    required this.hours,
    this.sameHoursAllDays = false,
  });

  factory OpeningHours.fromMap(Map<String, dynamic> map) {
    return OpeningHours(
      hours: Map<String, String>.from(map['hours'] ?? {}),
      sameHoursAllDays: map['sameHoursAllDays'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hours': hours,
      'sameHoursAllDays': sameHoursAllDays,
    };
  }

  bool isOpenNow() {
    final now = DateTime.now();
    final currentDay = now.weekday;
    final currentTime = now.hour * 60 + now.minute;
    final dayName = _getDayName(currentDay);
    final dayHours = hours[dayName] ?? "fermé";

    if (dayHours == "fermé") return false;

    final timeSlots = dayHours.split(' / ');
    for (var slot in timeSlots) {
      try {
        final [openTime, closeTime] =
            slot.split('-').map((e) => e.trim()).toList();
        final [openHour, openMinute] =
            openTime.split(':').map(int.parse).toList();
        final [closeHour, closeMinute] =
            closeTime.split(':').map(int.parse).toList();

        final openTimeMinutes = openHour * 60 + openMinute;
        final closeTimeMinutes = closeHour * 60 + closeMinute;

        if (currentTime >= openTimeMinutes && currentTime <= closeTimeMinutes) {
          return true;
        }
      } catch (e) {
        debugPrint('Erreur lors du parsing des horaires: $e');
        continue;
      }
    }

    return false;
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return '';
    }
  }
}
