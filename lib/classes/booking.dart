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
      bookingDate: (map['bookingDateTime'] ?? Timestamp.now()).toDate(),
      price: (map['price'] ?? 0).toDouble(),
      status: map['status'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Méthode adaptée pour la nouvelle structure unifiée des commandes
  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Vérifier si c'est une commande de service dans la structure unifiée
    if (data['type'] == 'service') {
      return BookingModel(
        id: doc.id,
        userId: data['userId'] ?? '',
        serviceId: data['serviceId'] ?? '',
        professionalId: data['professionalId'] ?? '',
        timeSlotId: data['timeSlotId'] ?? 'unified_${doc.id}', // Générer un timeSlotId factice
        bookingDate: (data['bookingDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        price: (data['amount'] ?? 0).toDouble(), // Utiliser 'amount' au lieu de 'price'
        status: data['status'] ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }
    
    // Pour les anciennes structures (si elles existent encore)
    return BookingModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      serviceId: data['serviceId'] ?? '',
      professionalId: data['professionalId'] ?? '',
      timeSlotId: data['timeSlotId'] ?? '',
      bookingDate: (data['bookingDateTime'] ?? Timestamp.now()).toDate(),
      price: (data['amount'] ?? data['price'] ?? 0).toDouble(),
      status: data['status'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
