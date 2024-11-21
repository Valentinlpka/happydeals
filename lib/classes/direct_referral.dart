// Créez d'abord une nouvelle classe pour les parrainages directs
import 'package:cloud_firestore/cloud_firestore.dart';

class DirectReferral {
  final String id;
  final String sponsorUid;
  final String refereeUid;
  final String companyId;
  final String companyName;
  final String sponsorName;
  final String sponsorEmail;
  final String refereeName;
  final String refereeContactType;
  final String refereeContact;
  final String message;
  final double urgencyLevel;
  final DateTime timestamp;
  final String status;

  DirectReferral({
    required this.id,
    required this.sponsorUid,
    required this.refereeUid,
    required this.companyId,
    required this.companyName,
    required this.sponsorName,
    required this.sponsorEmail,
    required this.refereeName,
    required this.refereeContactType,
    required this.refereeContact,
    required this.message,
    required this.urgencyLevel,
    required this.timestamp,
    this.status = 'Envoyé',
  });

  Map<String, dynamic> toMap() {
    return {
      'sponsorUid': sponsorUid,
      'refereeUid': refereeUid,
      'companyId': companyId,
      'companyName': companyName,
      'sponsorName': sponsorName,
      'sponsorEmail': sponsorEmail,
      'refereeName': refereeName,
      'refereeContactType': refereeContactType,
      'refereeContact': refereeContact,
      'message': message,
      'urgencyLevel': urgencyLevel,
      'timestamp': timestamp,
      'type': 'direct_referral',
      'status': status,
    };
  }

  factory DirectReferral.fromMap(String id, Map<String, dynamic> map) {
    return DirectReferral(
      id: id,
      sponsorUid: map['sponsorUid'] ?? '',
      refereeUid: map['refereeUid'] ?? '',
      companyId: map['companyId'] ?? '',
      companyName: map['companyName'] ?? '',
      sponsorName: map['sponsorName'] ?? '',
      sponsorEmail: map['sponsorEmail'] ?? '',
      refereeName: map['refereeName'] ?? '',
      refereeContactType: map['refereeContactType'] ?? '',
      refereeContact: map['refereeContact'] ?? '',
      message: map['message'] ?? '',
      urgencyLevel: (map['urgencyLevel'] ?? 4).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: map['status'] ?? 'Envoyé',
    );
  }
}
