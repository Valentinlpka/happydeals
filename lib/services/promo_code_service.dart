// lib/services/promo_code_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/promo_code.dart';

class PromoCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<PromoCode?> validatePromoCode(String code) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('promoCodes').doc(code).get();
      if (doc.exists) {
        PromoCode promoCode = PromoCode.fromFirestore(doc);
        if (promoCode.expirationDate.isAfter(DateTime.now())) {
          return promoCode;
        }
      }
      return null;
    } catch (e) {
      print('Erreur lors de la validation du code promo: $e');
      return null;
    }
  }
}
