import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/share_post.dart';
import 'package:happy/screens/marketplace/article_form.dart';
import 'package:happy/screens/marketplace/exchange_form.dart';
import 'package:happy/screens/marketplace/vehicle_form.dart';
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
  // Déclaration des GlobalKey pour chaque formulaire
  final GlobalKey<ArticleFormState> _articleFormKey =
      GlobalKey<ArticleFormState>();
  final GlobalKey<VehicleFormState> _vehicleFormKey =
      GlobalKey<VehicleFormState>();

  final GlobalKey<ExchangeFormState> _exchangeFormKey =
      GlobalKey<ExchangeFormState>();

  late Widget _form;

  @override
  void initState() {
    super.initState();
    _form = _getForm();
  }

  Widget _getForm() {
    switch (widget.adType) {
      case 'article':
        return ArticleForm(key: _articleFormKey, existingAd: widget.existingAd);
      case 'vehicle':
        return VehicleForm(key: _vehicleFormKey, existingAd: widget.existingAd);
      case 'exchange':
        return ExchangeForm(
            key: _exchangeFormKey, existingAd: widget.existingAd);
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer une annonce - ${_getAdTypeTitle(widget.adType)}'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _form,
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Publier l\'annonce'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAdTypeTitle(String adType) {
    switch (adType) {
      case 'article':
        return 'Article à vendre';
      case 'vehicle':
        return 'Véhicule à vendre';
      case 'property':
        return 'Bien immobilier';
      case 'exchange':
        return 'Troc et Échange';
      default:
        return 'Inconnu';
    }
  }

  Future<List<String>> _uploadPhotos(List<dynamic> photos) async {
    List<String> photoUrls = [];
    for (var photo in photos) {
      if (photo is String) {
        // C'est déjà une URL, on la garde telle quelle
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
          continue; // Skip if the photo is not in a recognized format
        }

        await uploadTask.whenComplete(() => null);
        String downloadUrl = await storageRef.getDownloadURL();
        photoUrls.add(downloadUrl);
      }
    }
    return photoUrls;
  }

  void _submitForm() async {
    Map<String, dynamic> formData = {};
    bool isValid = false;

    if (_form is ArticleForm) {
      formData = (_articleFormKey.currentState)?.getFormData() ?? {};
      isValid = formData.isNotEmpty;
    } else if (_form is VehicleForm) {
      formData = (_vehicleFormKey.currentState)?.getFormData() ?? {};
      isValid = formData.isNotEmpty;
    } else if (_form is ExchangeForm) {
      formData = (_exchangeFormKey.currentState)?.getFormData() ?? {};
      isValid = formData.isNotEmpty;
    }

    if (isValid && formData.containsKey('photos')) {
      try {
        User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception("Utilisateur non connecté");
        }

        List<String> photoUrls = await _uploadPhotos(formData['photos']);
        formData['photos'] = photoUrls;

        formData.addAll({
          'adType': widget.adType,
          'userId': currentUser.uid,
          'status': 'new',
        });

        if (widget.existingAd != null) {
          // Mise à jour d'une annonce existante
          await FirebaseFirestore.instance
              .collection('ads')
              .doc(widget.existingAd!.id)
              .update(formData);
        } else {
          // Création d'une nouvelle annonce
          formData['createdAt'] = FieldValue.serverTimestamp();
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

          // Ajouter le post partagé à Firestore
          await FirebaseFirestore.instance
              .collection('posts')
              .doc(sharedPost.id)
              .set(sharedPost.toMap());

          // Mettre à jour l'annonce avec l'ID du post partagé
          await newAdRef.update({'sharedPostId': sharedPost.id});
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.existingAd != null
                  ? 'Annonce mise à jour avec succès!'
                  : 'Annonce publiée avec succès!')),
        );

        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la publication: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez remplir tous les champs requis')),
      );
    }
  }
}
