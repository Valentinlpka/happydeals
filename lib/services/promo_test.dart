import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PromoCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> validateAndGetPromoCode(
    String code,
    String companyId,
    String userId, {
    String? serviceId,
    String? productId,
    double? cartTotal,
  }) async {
    try {
      // 1. Vérifier si le code existe et est valide pour l'entreprise
      final promoDoc = await _firestore
          .collection('promo_codes')
          .where('code', isEqualTo: code)
          .where('companyId', whereIn: [companyId, "UP"])
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      if (promoDoc.docs.isEmpty) {
        throw Exception('Code promo invalide ou expiré');
      }

      final promoData = promoDoc.docs.first.data();

      // 2. Vérifier si le code est applicable au type d'achat
      final String applicableTo = promoData['applicableTo'] ?? 'all';

      if (applicableTo == 'services' && serviceId == null) {
        throw Exception(
            'Ce code promo est valable uniquement pour les services');
      }

      if (applicableTo == 'products' && productId == null) {
        throw Exception(
            'Ce code promo est valable uniquement pour les produits');
      }

      // 3. Vérifier les limites d'utilisation
      final maxUses = int.tryParse(promoData['maxUses'] ?? '0') ?? 0;
      final currentUses = promoData['currentUses'] ?? 0;
      if (maxUses > 0 && currentUses >= maxUses) {
        throw Exception(
            'Ce code promo a atteint son nombre maximum d\'utilisations');
      }

      // 4. Vérifier si l'utilisateur a déjà utilisé ce code
      final usageHistory = List<String>.from(promoData['usageHistory'] ?? []);
      if (usageHistory.contains(userId)) {
        throw Exception('Vous avez déjà utilisé ce code promo');
      }

      // 5. Vérifier les conditions spécifiques
      final conditionType = promoData['conditionType'] as String? ?? 'none';
      final conditionValue = promoData['conditionValue'] ?? 0;
      final conditionProductId = promoData['conditionProductId'] as String?;

      if (conditionType == 'amount' && cartTotal != null) {
        if (cartTotal < conditionValue) {
          throw Exception(
              'Le montant minimum d\'achat doit être de ${conditionValue.toStringAsFixed(2)}€');
        }
      }

      if (conditionType == 'quantity' &&
          conditionProductId?.isNotEmpty == true) {
        if (productId != conditionProductId) {
          // Récupérer le nom du produit requis
          final productDoc = await _firestore
              .collection('products')
              .doc(conditionProductId)
              .get();
          final productName = productDoc.data()?['name'] ?? 'ce produit';
          throw Exception(
              'Ce code nécessite l\'achat de $conditionValue $productName(s)');
        }
      }

      return {
        'id': promoDoc.docs.first.id,
        'code': code,
        'applicableTo': applicableTo,
        'discountType': promoData['discountType'],
        'discountValue': (promoData['discountValue'] as num).toDouble(),
        'conditionType': conditionType,
        'conditionValue': conditionValue,
        'conditionProductId': conditionProductId,
        'sellerId': promoData['sellerId'],
        ...promoData,
      };
    } catch (e) {
      debugPrint('Erreur lors de la validation du code promo: $e');
      rethrow;
    }
  }

  Future<void> usePromoCode(String promoId, String userId) async {
    try {
      await _firestore.collection('promo_codes').doc(promoId).update({
        'currentUses': FieldValue.increment(1),
        'usageHistory': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Erreur lors de l\'utilisation du code promo: $e');
      throw Exception('Erreur lors de l\'application du code promo');
    }
  }

  double calculateDiscount(
      Map<String, dynamic> promoDetails, double originalPrice) {
    final discountType = promoDetails['discountType'];
    final discountValue = promoDetails['discountValue'] as double;

    if (discountType == 'percentage') {
      final reduction = originalPrice * (discountValue / 100);
      return reduction > originalPrice ? originalPrice : reduction;
    } else {
      return discountValue > originalPrice ? originalPrice : discountValue;
    }
  }
}
