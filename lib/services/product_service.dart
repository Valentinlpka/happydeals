// lib/services/product_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/product.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Product>> getProductsForSeller(String sellerId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('products')
        .where('merchantId', isEqualTo: sellerId)
        .get();
    return snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList();
  }

  Future<Product> getProduct(String productId) async {
    DocumentSnapshot doc =
        await _firestore.collection('products').doc(productId).get();
    return Product.fromFirestore(doc);
  }
}
