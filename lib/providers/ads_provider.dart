import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SavedAdsProvider extends ChangeNotifier {
  final Set<String> _savedAds = {};
  bool _isInitialized = false;

  bool isAdSaved(String adId) => _savedAds.contains(adId);

  Future<void> initializeSavedAds(String userId) async {
    if (_isInitialized) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      _savedAds.clear();
      final savedAdsList = List<String>.from(userDoc.data()?['savedAds'] ?? []);
      _savedAds.addAll(savedAdsList);
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
    }
  }

  Future<void> toggleSaveAd(String userId, String adId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        List<String> savedAds =
            List<String>.from(userDoc.data()?['savedAds'] ?? []);

        if (savedAds.contains(adId)) {
          savedAds.remove(adId);
          _savedAds.remove(adId);
        } else {
          savedAds.add(adId);
          _savedAds.add(adId);
        }

        transaction.update(userRef, {'savedAds': savedAds});
      });

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void reset() {
    _savedAds.clear();
    _isInitialized = false;
    notifyListeners();
  }
}
