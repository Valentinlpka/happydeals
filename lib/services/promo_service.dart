import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> validatePromoCode(
    String code,
    String companyId,
    String customerId,
  ) async {

    try {
      final loyaltyPromoDoc = await _firestore
          .collection('PromoCodes')
          .where('code', isEqualTo: code)
          .where('companyId', isEqualTo: companyId)
          .where('customerId', isEqualTo: customerId)
          .where('usedAt', isNull: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      if (loyaltyPromoDoc.docs.isNotEmpty) {
        return true;
      }
    } catch (e) {
      // L'erreur contiendra le lien pour créer l'index
    }


    try {
      final storePromoDoc = await _firestore
          .collection('posts')
          .where('type', isEqualTo: 'promo_code')
          .where('code', isEqualTo: code)
          .where('sellerId', isEqualTo: companyId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .where('isActive', isEqualTo: true)
          .get();

      if (storePromoDoc.docs.isEmpty) return false;

      final promoPost = storePromoDoc.docs.first;
      final data = promoPost.data();

      final maxUses = data['maxUses'];
      final currentUses = data['currentUses'] ?? 0;

      if (maxUses != null && currentUses >= maxUses) {
        return false;
      }

      return true;
    } catch (e) {
      // L'erreur contiendra le lien pour créer l'index
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPromoCodeDetails(String code) async {
    // D'abord, chercher dans les codes de fidélité
    final loyaltyPromoDoc = await _firestore
        .collection('PromoCodes')
        .where('code', isEqualTo: code)
        .get();

    if (loyaltyPromoDoc.docs.isNotEmpty) {
      return loyaltyPromoDoc.docs.first.data();
    }

    // Sinon, chercher dans les codes promo boutique
    final storePromoDoc = await _firestore
        .collection('posts')
        .where('type', isEqualTo: 'promo_code')
        .where('code', isEqualTo: code)
        .get();

    if (storePromoDoc.docs.isNotEmpty) {
      final data = storePromoDoc.docs.first.data();
      return {
        'code': data['code'],
        'value': data['value'],
        'isPercentage': data['isPercentage'],
        'companyId': data['companyId'],
        'maxUses': data['maxUses'],
        'currentUses': data['currentUses'] ?? 0,
        'isStoreWide': data['isStoreWide'] ?? true,
        'applicableProductIds': data['applicableProductIds'] ?? [],
      };
    }

    return null;
  }

  Future<void> usePromoCode(String code, String companyId) async {
    // D'abord, essayer de mettre à jour un code de fidélité
    final loyaltyPromoDoc = await _firestore
        .collection('PromoCodes')
        .where('code', isEqualTo: code)
        .where('companyId', isEqualTo: companyId)
        .get();

    if (loyaltyPromoDoc.docs.isNotEmpty) {
      await loyaltyPromoDoc.docs.first.reference.update({
        'usedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Sinon, mettre à jour le compteur d'utilisation du code promo boutique
    final storePromoDoc = await _firestore
        .collection('posts')
        .where('type', isEqualTo: 'promo_code')
        .where('code', isEqualTo: code)
        .where('sellerId', isEqualTo: companyId)
        .get();

    if (storePromoDoc.docs.isNotEmpty) {
      await storePromoDoc.docs.first.reference.update({
        'currentUses': FieldValue.increment(1),
      });
    }
  }

  // Méthode helper pour vérifier si le code promo est applicable aux produits
  Future<bool> isPromoCodeApplicableToProducts(
    String code,
    String companyId,
    List<String> productIds,
  ) async {
    final details = await getPromoCodeDetails(code);
    if (details == null) return false;

    // Si le code est store-wide, il s'applique à tous les produits
    if (details['isStoreWide'] == true) return true;

    // Sinon, vérifier que tous les produits sont dans la liste des produits applicables
    final applicableProductIds =
        List<String>.from(details['applicableProductIds'] ?? []);
    return productIds.every((id) => applicableProductIds.contains(id));
  }
}
