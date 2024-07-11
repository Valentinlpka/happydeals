import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  String? firstName;
  String? lastName;
  String? phoneNumber;
  String? address;
  bool isProfileComplete;
  String? stripeCustomerId;

  UserModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phoneNumber,
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
      'phoneNumber': phoneNumber,
      'address': address,
      'isProfileComplete': isProfileComplete,
      'stripeCustomerId': stripeCustomerId,
    };
  }
}
