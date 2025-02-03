import 'package:cloud_firestore/cloud_firestore.dart';

class Association {
  final String id;
  final String name;
  final String description;
  final String logo;
  final String cover;
  final String email;
  final String phone;
  final String category;
  final Address address;
  final Map<String, dynamic> openingHours;
  final int followersCount;
  final List<String> followers;
  final DateTime createdAt;
  final bool isVerified;
  final String website;
  final List<String> socialLinks;
  final List<String> donationNeeds;

  Association({
    required this.id,
    required this.name,
    required this.description,
    required this.logo,
    required this.cover,
    required this.email,
    required this.phone,
    required this.category,
    required this.address,
    required this.openingHours,
    this.followersCount = 0,
    this.followers = const [],
    required this.createdAt,
    this.isVerified = false,
    this.website = '',
    this.socialLinks = const [],
    this.donationNeeds = const [],
  });

  factory Association.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Association(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      logo: data['logo'] ?? '',
      cover: data['cover'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      category: data['category'] ?? '',
      address: Address.fromMap(data['address'] ?? {}),
      openingHours: Map<String, dynamic>.from(data['openingHours'] ?? {}),
      followersCount: data['followersCount'] ?? 0,
      followers: List<String>.from(data['followers'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isVerified: data['isVerified'] ?? false,
      website: data['website'] ?? '',
      socialLinks: List<String>.from(data['socialLinks'] ?? []),
      donationNeeds: List<String>.from(data['donationNeeds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'logo': logo,
      'cover': cover,
      'email': email,
      'phone': phone,
      'category': category,
      'address': address.toMap(),
      'openingHours': openingHours,
      'followersCount': followersCount,
      'followers': followers,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVerified': isVerified,
      'website': website,
      'socialLinks': socialLinks,
      'donationNeeds': donationNeeds,
    };
  }
}

class Address {
  final String street;
  final String postalCode;
  final String city;
  final String country;
  final double latitude;
  final double longitude;

  Address({
    required this.street,
    required this.postalCode,
    required this.city,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      street: map['street'] ?? '',
      postalCode: map['postalCode'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'postalCode': postalCode,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
