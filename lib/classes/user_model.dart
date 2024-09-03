import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  String? firstName;
  String? lastName;
  String? phoneNumber;
  String? image_profile;
  String? address;
  bool isProfileComplete;
  String? stripeCustomerId;

  UserModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.image_profile,
    this.address,
    this.isProfileComplete = false,
    this.stripeCustomerId,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'],
      image_profile: data['image_profile'],
      lastName: data['lastName'],
      phoneNumber: data['phoneNumber'],
      address: data['address'],
      isProfileComplete: data['isProfileComplete'] ?? false,
      stripeCustomerId: data['stripeCustomerId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'image_profile': image_profile,
      'phoneNumber': phoneNumber,
      'address': address,
      'isProfileComplete': isProfileComplete,
      'stripeCustomerId': stripeCustomerId,
    };
  }
}
