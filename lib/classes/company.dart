import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String sellerId;
  final Address adress;
  final Map<String, dynamic> openingHours;
  final double averageRating;
  final int numberOfReviews;
  final DateTime createdAt;

  Company({
    required this.id,
    required this.name,
    required this.entityType,
    required this.categorie,
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
    this.averageRating = 0.0,
    this.numberOfReviews = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Company.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      entityType: data['entityType'] ?? '',
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
      openingHours: Map<String, dynamic>.from(data['openingHours'] ?? {}),
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      numberOfReviews: data['numberOfReviews'] ?? 0,
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
      'email': email,
      'like': like,
      'logo': logo,
      'gallery': gallery,
      'phone': phone,
      'type': type,
      'sellerId': sellerId,
      'adress': adress.toMap(),
      'openingHours': openingHours,
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
  final double latitude;
  final double longitude;

  Address({
    required this.adresse,
    required this.codePostal,
    required this.pays,
    required this.ville,
    required this.longitude,
    required this.latitude,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      adresse: map['adresse'] ?? '',
      codePostal: map['code_postal'] ?? '',
      pays: map['pays'] ?? '',
      ville: map['ville'] ?? '',
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adresse': adresse,
      'code_postal': codePostal,
      'pays': pays,
      'ville': ville,
    };
  }
}
