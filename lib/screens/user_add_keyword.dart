import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserKeyWord extends StatelessWidget {
  const UserKeyWord({super.key});

  Future<void> updateAllUsersWithSearchName() async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    WriteBatch batch = firestore.batch();
    int batchSize = 0;

    QuerySnapshot snapshot = await firestore.collection('users').get();

    for (DocumentSnapshot doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String firstName = data['firstName'] ?? '';
      String lastName = data['lastName'] ?? '';

      List<String> searchName = generateSearchKeywords('$firstName $lastName');

      batch.update(doc.reference, {'searchName': searchName});
      batchSize++;

      // Firebase permet un maximum de 500 opérations par lot
      if (batchSize >= 500) {
        await batch.commit();
        batch = firestore.batch();
        batchSize = 0;
      }
    }

    // Commit any remaining changes
    if (batchSize > 0) {
      await batch.commit();
    }

    print('Mise à jour terminée pour ${snapshot.docs.length} utilisateurs');
  }

  List<String> generateSearchKeywords(String fullName) {
    List<String> keywords = [];
    String name = fullName.toLowerCase();

    List<String> nameParts = name.split(' ');

    for (String part in nameParts) {
      for (int i = 1; i <= part.length; i++) {
        keywords.add(part.substring(0, i));
      }
    }

    // Ajoutez le nom complet
    keywords.add(name);

    // Retirez les doublons
    return keywords.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
          onPressed: () => updateAllUsersWithSearchName(),
          child: const Text('Mettre a jour')),
    );
  }
}
