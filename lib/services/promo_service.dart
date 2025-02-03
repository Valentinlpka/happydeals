import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> validatePromoCode(
    String code,
    String companyId,
    String customerId,
  ) async {
    try {
      final promoDoc = await _firestore
          .collection('promo_codes')
          .where('code', isEqualTo: code)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      if (promoDoc.docs.isEmpty) {
        print('Code promo non trouvé ou expiré');
        return false;
      }

      final data = promoDoc.docs.first.data();
      print('Document trouvé: ${data.toString()}');

      // Vérifier les limites d'utilisation
      final maxUses = int.tryParse(data['maxUses'].toString()) ?? 0;
      final currentUses = data['currentUses'] ?? 0;
      if (maxUses > 0 && currentUses >= maxUses) {
        print('Code promo a atteint le nombre maximum d\'utilisations');
        throw Exception(
            'Ce code promo a atteint son nombre maximum d\'utilisations');
      }

      // Vérifier l'historique d'utilisation
      final usageHistory = List<String>.from(data['usageHistory'] ?? []);
      if (usageHistory.contains(customerId)) {
        print('L\'utilisateur a déjà utilisé ce code promo');
        throw Exception('Vous avez déjà utilisé ce code promo');
      }

      return true;
    } catch (e) {
      print('Erreur lors de la validation du code promo: $e');
      if (e is Exception) {
        rethrow;
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPromoCodeDetails(String code) async {
    final promoDoc = await _firestore
        .collection('promo_codes')
        .where('code', isEqualTo: code)
        .get();

    if (promoDoc.docs.isNotEmpty) {
      final data = promoDoc.docs.first.data();

      // Convertir discountValue en nombre
      double discountValue;
      try {
        // Convertir en double quelle que soit la forme d'origine
        discountValue = double.parse(data['discountValue'].toString());
      } catch (e) {
        print('Erreur lors de la conversion de discountValue: $e');
        return null;
      }

      return {
        'code': data['code'],
        'value': discountValue,
        'isPercentage': data['discountType'] == 'percentage',
        'companyId': data['companyId'],
        'maxUses': int.tryParse(data['maxUses'].toString()) ?? 0,
        'currentUses': data['currentUses'] ?? 0,
        'conditionType': data['conditionType'],
        'conditionValue': data['conditionValue'],
        'conditionProductId': data['conditionProductId'],
        'description': data['description'],
        'expiresAt': data['expiresAt'],
        'isActive': data['isActive'],
        'usageHistory': data['usageHistory'] ?? [],
        'isPublic': data['isPublic'] ?? false,
        'timestamp': data['timestamp'],
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
        'sellerId': data['sellerId'],
      };
    }

    return null;
  }

  Future<void> usePromoCode(
    String code,
    String companyId,
    String customerId,
  ) async {
    try {
      final promoDoc = await _firestore
          .collection('promo_codes')
          .where('code', isEqualTo: code)
          .where('companyId', isEqualTo: companyId)
          .get();

      if (promoDoc.docs.isNotEmpty) {
        final updates = {
          'currentUses': FieldValue.increment(1),
          'usageHistory': FieldValue.arrayUnion([customerId]),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await promoDoc.docs.first.reference.update(updates);
      }
    } catch (e) {
      print('Erreur lors de l\'utilisation du code promo: $e');
      throw Exception('Erreur lors de l\'application du code promo');
    }
  }

  Future<bool> isPromoCodeApplicableToProducts(
    String code,
    String companyId,
    List<String> productIds,
    Map<String, int> productQuantities,
  ) async {
    final details = await getPromoCodeDetails(code);
    if (details == null) return false;

    print('Vérification des conditions du code promo:');
    print('Type de condition: ${details['conditionType']}');
    print('Produit requis: ${details['conditionProductId']}');
    print('Quantité requise: ${details['conditionValue']}');

    if (details['conditionType'] == 'quantity' &&
        details['conditionProductId'] != null) {
      final requiredProductId = details['conditionProductId'];
      final requiredQuantity = details['conditionValue'] ?? 0;

      print('Vérification du produit requis:');
      print('- ID du produit requis: $requiredProductId');
      print('- Quantité requise: $requiredQuantity');
      print('- Produits dans le panier: $productIds');
      print('- Quantités dans le panier: $productQuantities');

      // Récupérer les informations du produit requis
      final productDoc =
          await _firestore.collection('products').doc(requiredProductId).get();

      if (!productDoc.exists) {
        throw Exception('Le produit requis pour ce code promo n\'existe plus');
      }

      final productData = productDoc.data()!;
      final productName = productData['name'] ?? 'produit inconnu';

      // Vérifier si le produit est dans le panier
      if (!productIds.contains(requiredProductId)) {
        print('Produit requis non trouvé dans le panier: $productName');
        throw Exception(
            'Ce code promo nécessite l\'achat de $requiredQuantity $productName(s)');
      }

      // Vérifier si la quantité requise est atteinte
      final actualQuantity = productQuantities[requiredProductId] ?? 0;
      print(
          'Quantité trouvée dans le panier: $actualQuantity/$requiredQuantity');

      if (actualQuantity < requiredQuantity) {
        throw Exception(
            'Ce code promo nécessite l\'achat de $requiredQuantity $productName(s). Vous en avez actuellement $actualQuantity dans votre panier.');
      }

      print('Conditions de quantité satisfaites pour le produit: $productName');
    }

    return true;
  }
}
