import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/user_referral.dart';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserReferral> getUserReferral(String referralId) async {
    DocumentSnapshot referralDoc =
        await _firestore.collection('referrals').doc(referralId).get();

    if (!referralDoc.exists) {
      throw Exception('Parrainage utilisateur non trouvé');
    }

    return UserReferral.fromDocument(referralDoc);
  }

  Future<Referral> getReferralPost(String postId) async {
    DocumentSnapshot postDoc =
        await _firestore.collection('posts').doc(postId).get();

    if (!postDoc.exists) {
      throw Exception('Post de parrainage non trouvé');
    }

    return Referral.fromDocument(postDoc);
  }

  Future<Map<String, String>> getCompanyInfo(String companyId) async {
    DocumentSnapshot companyDoc =
        await _firestore.collection('companys').doc(companyId).get();

    if (!companyDoc.exists) {
      throw Exception('Entreprise non trouvée');
    }

    final data = companyDoc.data() as Map<String, dynamic>;
    return {
      'companyName': data['name'] ?? '',
      'companyLogo': data['logo'] ?? '',
    };
  }

  Future<List<UserReferral>> getUserReferrals(String userId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('referrals')
        .where('sponsorUid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => UserReferral.fromDocument(doc)).toList();
  }
}
