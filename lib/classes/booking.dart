import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String userId;
  final String serviceId;
  final String professionalId;
  final String timeSlotId;
  final DateTime bookingDate;
  final double price;
  final String status;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.userId,
    required this.serviceId,
    required this.professionalId,
    required this.timeSlotId,
    required this.bookingDate,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'serviceId': serviceId,
      'professionalId': professionalId,
      'timeSlotId': timeSlotId,
      'bookingDate': bookingDate,
      'price': price,
      'status': status,
      'createdAt': createdAt,
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      serviceId: map['serviceId'] ?? '',
      professionalId: map['professionalId'] ?? '',
      timeSlotId: map['timeSlotId'] ?? '',
      bookingDate: (map['bookingDate'] as Timestamp).toDate(),
      price: (map['price'] ?? 0).toDouble(),
      status: map['status'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
