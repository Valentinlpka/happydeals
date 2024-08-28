import 'package:cloud_firestore/cloud_firestore.dart';

class UserReferral {
  final String id;
  final String message;
  final String companyName;
  final String type;
  final String refereeContact;
  final String refereeContactType;
  final String refereeName;
  final String referralId;
  final String sponsorEmail;
  final String sponsorName;
  final String sponsorUid;
  final DateTime timestamp;
  final String status;

  UserReferral({
    required this.id,
    required this.type,
    required this.companyName,
    required this.status,
    required this.message,
    required this.refereeContact,
    required this.refereeContactType,
    required this.refereeName,
    required this.referralId,
    required this.sponsorEmail,
    required this.sponsorName,
    required this.sponsorUid,
    required this.timestamp,
  });

  factory UserReferral.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserReferral(
      id: doc.id,
      message: data['message'] ?? '',
      companyName: data['companyName'] ?? '',
      type: data['type'] ?? '',
      status: data['etat'] ?? '',
      refereeContact: data['refereeContact'] ?? '',
      refereeContactType: data['refereeContactType'] ?? '',
      refereeName: data['refereeName'] ?? '',
      referralId: data['referralId'],
      sponsorEmail: data['sponsorEmail'] ?? '',
      sponsorName: data['sponsorName'] ?? '',
      sponsorUid: data['sponsorUid'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}
