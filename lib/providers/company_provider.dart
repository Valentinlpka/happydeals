import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/company.dart';

class CompanyLikeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId;
  Set<String> _likedCompanies = {};

  CompanyLikeService(this.userId) {
    _loadLikedCompanies();
  }

  bool isCompanyLiked(String companyId) {
    return _likedCompanies.contains(companyId);
  }

  Future<void> _loadLikedCompanies() async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final likedCompanies =
        userDoc.data()?['likedCompanies'] as List<dynamic>? ?? [];
    _likedCompanies = Set<String>.from(likedCompanies.cast<String>());
    notifyListeners();
  }

  Future<Company> handleLike(Company company) async {
    final companyRef = _firestore.collection('companys').doc(company.id);
    final userRef = _firestore.collection('users').doc(userId);

    Company updatedCompany;

    // Mise à jour optimiste de l'état local
    if (_likedCompanies.contains(company.id)) {
      _likedCompanies.remove(company.id);
      updatedCompany = company.copyWith(like: company.like - 1);
    } else {
      _likedCompanies.add(company.id);
      updatedCompany = company.copyWith(like: company.like + 1);
    }
    notifyListeners();

    // Mise à jour Firestore en arrière-plan
    try {
      await _firestore.runTransaction((transaction) async {
        final companySnapshot = await transaction.get(companyRef);
        final userSnapshot = await transaction.get(userRef);

        if (!companySnapshot.exists || !userSnapshot.exists) {
          throw Exception("Le document n'existe pas !");
        }

        final companyData = companySnapshot.data() ?? {};
        final List<String> likedBy =
            List<String>.from(companyData['likedBy'] ?? []);
        final int likes = companyData['like'] ?? 0;

        Map<String, dynamic> updateData;

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          updateData = {
            'likedBy': likedBy,
            'like': likes - 1,
          };
          transaction.update(userRef, {
            'likedCompanies': FieldValue.arrayRemove([company.id])
          });
        } else {
          likedBy.add(userId);
          updateData = {
            'likedBy': likedBy,
            'like': likes + 1,
          };
          transaction.update(userRef, {
            'likedCompanies': FieldValue.arrayUnion([company.id])
          });
        }

        // Mise à jour du document de l'entreprise
        transaction.set(companyRef, updateData, SetOptions(merge: true));
      });
    } catch (e) {
      // Annulation de la mise à jour optimiste si la transaction Firestore échoue
      if (_likedCompanies.contains(company.id)) {
        _likedCompanies.remove(company.id);
        updatedCompany = company.copyWith(like: company.like - 1);
      } else {
        _likedCompanies.add(company.id);
        updatedCompany = company.copyWith(like: company.like + 1);
      }
      notifyListeners();
      print("Erreur lors de la gestion du like : $e");
    }

    return updatedCompany;
  }
}

// Ajoutez cette méthode à votre classe Company
extension CompanyExtension on Company {
  Company copyWith({
    String? id,
    String? name,
    String? categorie,
    String? cover,
    String? description,
    String? email,
    int? like,
    String? logo,
    String? phone,
    String? sellerId,
    Address? adress,
    Map<String, String>? openingHours,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      categorie: categorie ?? this.categorie,
      cover: cover ?? this.cover,
      description: description ?? this.description,
      email: email ?? this.email,
      like: like ?? this.like,
      logo: logo ?? this.logo,
      phone: phone ?? this.phone,
      sellerId: sellerId ?? this.sellerId,
      adress: adress ?? this.adress,
      openingHours: openingHours ?? this.openingHours,
    );
  }
}
