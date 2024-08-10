import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UpdateSearchableFieldsScreen extends StatefulWidget {
  const UpdateSearchableFieldsScreen({super.key});

  @override
  _UpdateSearchableFieldsScreenState createState() =>
      _UpdateSearchableFieldsScreenState();
}

class _UpdateSearchableFieldsScreenState
    extends State<UpdateSearchableFieldsScreen> {
  bool isUpdating = false;
  String updateStatus = '';

  String normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y')
        .replaceAll(RegExp(r'[ñ]'), 'n');
  }

  Future<void> updateSearchableFields() async {
    setState(() {
      isUpdating = true;
      updateStatus = 'Mise à jour en cours...';
    });

    try {
      final postsRef = FirebaseFirestore.instance.collection('companys');
      final snapshot = await postsRef.get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshot.docs) {
        final normalizedTitle = normalizeText(doc.data()['name'] ?? '');
        batch.update(doc.reference, {'searchText': normalizedTitle});
      }

      await batch.commit();
      setState(() {
        updateStatus = 'Mise à jour terminée avec succès!';
      });
    } catch (error) {
      print('Erreur lors de la mise à jour: $error');
      setState(() {
        updateStatus = 'Erreur lors de la mise à jour. Veuillez réessayer.';
      });
    } finally {
      setState(() {
        isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mise à jour des champs de recherche')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isUpdating ? null : updateSearchableFields,
              child: const Text('Mettre à jour les champs de recherche'),
            ),
            const SizedBox(height: 20),
            Text(updateStatus),
          ],
        ),
      ),
    );
  }
}
