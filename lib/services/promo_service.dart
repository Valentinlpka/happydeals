// promo_code_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> validatePromoCode(
      String code, String companyId, String customerId) async {
    final promoCodeDoc = await _firestore
        .collection('PromoCodes')
        .where('code', isEqualTo: code)
        .where('companyId', isEqualTo: companyId)
        .where('customerId', isEqualTo: customerId)
        .where('usedAt', isNull: true)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .get();

    return promoCodeDoc.docs.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getPromoCodeDetails(String code) async {
    final promoCodeDoc = await _firestore
        .collection('PromoCodes')
        .where('code', isEqualTo: code)
        .get();

    if (promoCodeDoc.docs.isNotEmpty) {
      return promoCodeDoc.docs.first.data();
    }
    return null;
  }

  Future<void> usePromoCode(String code) async {
    final promoCodeDoc = await _firestore
        .collection('PromoCodes')
        .where('code', isEqualTo: code)
        .get();

    if (promoCodeDoc.docs.isNotEmpty) {
      await promoCodeDoc.docs.first.reference.update({
        'usedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
