import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/association.dart';

class AssociationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Association> _associations = [];
  bool _isLoading = false;
  String? _error;

  List<Association> get associations => _associations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAssociations() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final snapshot = await _firestore.collection('associations').get();
      _associations =
          snapshot.docs.map((doc) => Association.fromFirestore(doc)).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFollow(String associationId, String userId) async {
    try {
      final associationRef =
          _firestore.collection('associations').doc(associationId);
      final associationDoc = await associationRef.get();

      if (!associationDoc.exists) return;

      final association = Association.fromFirestore(associationDoc);
      final isFollowing = association.followers.contains(userId);

      if (isFollowing) {
        await associationRef.update({
          'followers': FieldValue.arrayRemove([userId]),
          'followersCount': FieldValue.increment(-1),
        });
      } else {
        await associationRef.update({
          'followers': FieldValue.arrayUnion([userId]),
          'followersCount': FieldValue.increment(1),
        });
      }

      await loadAssociations();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<Association?> getAssociationById(String id) async {
    try {
      final doc = await _firestore.collection('associations').doc(id).get();
      if (!doc.exists) return null;
      return Association.fromFirestore(doc);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
