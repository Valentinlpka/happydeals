import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/screens/marketplace/exchange_form.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class AdCreationScreen extends StatefulWidget {
  final String adType;
  final Ad? existingAd;

  const AdCreationScreen({super.key, required this.adType, this.existingAd});

  @override
  _AdCreationScreenState createState() => _AdCreationScreenState();
}

class _AdCreationScreenState extends State<AdCreationScreen> {
  final GlobalKey<ExchangeFormState> _exchangeFormKey =
      GlobalKey<ExchangeFormState>();
  late Widget _form;

  @override
  void initState() {
    super.initState();
    _form = ExchangeForm(key: _exchangeFormKey, existingAd: widget.existingAd);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingAd != null
              ? 'Modifier l\'annonce'
              : 'Créer une annonce',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _form,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.existingAd != null
                  ? 'Mettre à jour'
                  : 'Publier l\'annonce',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<String>> _uploadPhotos(List<dynamic> photos) async {
    List<String> photoUrls = [];
    for (var photo in photos) {
      if (photo is String) {
        photoUrls.add(photo);
      } else {
        String fileName = const Uuid().v4();
        Reference storageRef =
            FirebaseStorage.instance.ref().child('ad_photos/$fileName');

        UploadTask uploadTask;
        if (photo is XFile) {
          uploadTask = storageRef.putFile(File(photo.path));
        } else if (photo is Uint8List) {
          uploadTask = storageRef.putData(photo);
        } else {
          continue;
        }

        await uploadTask.whenComplete(() => null);
        String downloadUrl = await storageRef.getDownloadURL();
        photoUrls.add(downloadUrl);
      }
    }
    return photoUrls;
  }

  void _submitForm() async {
    Map<String, dynamic> formData =
        _exchangeFormKey.currentState?.getFormData() ?? {};

    if (formData.isNotEmpty &&
        formData.containsKey('photos') &&
        formData.containsKey('title')) {
      try {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception("Utilisateur non connecté");
        }

        List<String> photoUrls = await _uploadPhotos(formData['photos']);
        formData['photos'] = photoUrls;

        formData.addAll({
          'adType': 'exchange',
          'userId': currentUser.uid,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (widget.existingAd != null) {
          await FirebaseFirestore.instance
              .collection('ads')
              .doc(widget.existingAd!.id)
              .update(formData);
        } else {
          DocumentReference newAdRef =
              await FirebaseFirestore.instance.collection('ads').add(formData);

          SharedPost sharedPost = SharedPost(
            id: FirebaseFirestore.instance.collection('posts').doc().id,
            companyId: formData['companyId'] ?? '',
            timestamp: DateTime.now(),
            originalPostId: newAdRef.id,
            sharedBy: currentUser.uid,
            sharedAt: DateTime.now(),
            comment: "a publié une annonce",
          );

          await FirebaseFirestore.instance
              .collection('posts')
              .doc(sharedPost.id)
              .set(sharedPost.toMap());

          await newAdRef.update({'sharedPostId': sharedPost.id});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.existingAd != null
                    ? 'Annonce mise à jour avec succès!'
                    : 'Annonce publiée avec succès!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la publication: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs requis'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
