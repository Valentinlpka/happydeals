import 'package:cloud_firestore/cloud_firestore.dart';

class TimeSlotModel {
  final String id;
  final String serviceId;
  final String professionalId;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAvailable;
  final String? bookedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimeSlotModel({
    required this.id,
    required this.serviceId,
    required this.professionalId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
    this.bookedByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serviceId': serviceId,
      'professionalId': professionalId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
      'bookedByUserId': bookedByUserId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory TimeSlotModel.fromMap(Map<String, dynamic> map) {
    return TimeSlotModel(
      id: map['id'] ?? '',
      serviceId: map['serviceId'] ?? '',
      professionalId: map['professionalId'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      isAvailable: map['isAvailable'] ?? true,
      bookedByUserId: map['bookedByUserId'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}
