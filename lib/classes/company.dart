import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String id;
  final String name;
  final String categorie;
  final bool open;
  final double rating;
  final int like;
  final String ville;
  final String phone;
  final String logo;
  final String description;
  final String website;
  final String address;
  final String email;

  Company({
    required this.id,
    required this.name,
    required this.categorie,
    required this.open,
    required this.rating,
    required this.like,
    required this.ville,
    required this.phone,
    required this.logo,
    required this.description,
    required this.website,
    required this.address,
    required this.email,
  });

  // Méthode pour convertir un document Firestore en objet Company
  factory Company.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      categorie: data['categorie'] ?? '',
      open: data['open'] ?? false,
      rating: data['rating']?.toDouble() ?? 0.0,
      like: data['like'] ?? 0,
      ville: data['ville'] ?? '',
      phone: data['phone'] ?? '',
      logo: data['logo'] ?? '',
      description: data['description'] ?? '',
      website: data['website'] ?? '',
      address: data['address'] ?? '',
      email: data['email'] ?? '',
    );
  }

  // Méthode pour convertir un objet Company en map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'categorie': categorie,
      'open': open,
      'rating': rating,
      'like': like,
      'ville': ville,
      'phone': phone,
      'logo': logo,
      'description': description,
      'website': website,
      'address': address,
      'email': email,
    };
  }
}
