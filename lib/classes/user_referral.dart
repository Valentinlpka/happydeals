import 'package:cloud_firestore/cloud_firestore.dart';

class UserReferral {
  final String message;
  final String refereeContact;
  final String refereeContactType;
  final String refereeName;
  final String referralId;
  final String sponsorEmail;
  final String sponsorName;
  final String sponsorUid;
  final DateTime timestamp;

  UserReferral({
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
      message: data['message'] ?? '',
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
