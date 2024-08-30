import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfileCompletionPage extends StatefulWidget {
  const ProfileCompletionPage({super.key});

  @override
  _ProfileCompletionPageState createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  bool _isLoading = false;
  File? _imageFile;
  bool _isImageUploaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenue !',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Complétez votre profil pour commencer',
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 48),
                _buildInputField(
                  controller: _firstNameController,
                  placeholder: 'Prénom',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 24),
                _buildInputField(
                  controller: _lastNameController,
                  placeholder: 'Nom',
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),
                const Text('Photo de profil'),
                _buildImagePicker(),
                const SizedBox(height: 48),
                _buildCompleteButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String placeholder,
    required TextInputAction textInputAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(placeholder),
        const SizedBox(
          height: 8,
        ),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 20,
            ),
          ),
          style: const TextStyle(fontSize: 17),
          textInputAction: textInputAction,
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5,
            shape: BoxShape.circle,
            image: _imageFile != null
                ? DecorationImage(
                    image: FileImage(_imageFile!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: _imageFile == null
              ? const Icon(
                  CupertinoIcons.camera,
                  size: 40,
                  color: CupertinoColors.systemGrey,
                )
              : _isImageUploaded
                  ? Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeGreen.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.checkmark_alt,
                        color: CupertinoColors.white,
                        size: 40,
                      ),
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        onPressed: _isLoading ? null : _completeProfile,
        color: CupertinoColors.activeBlue,
        borderRadius: BorderRadius.circular(8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: _isLoading
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : const Text(
                'Terminer',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          IOSUiSettings(
            title: 'Recadrer la photo',
            cancelButtonTitle: 'Annuler',
            doneButtonTitle: 'Terminer',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _imageFile = File(croppedFile.path);
          _isImageUploaded = false;
        });
        await _uploadImage();
      }
    }
  }

  Future<String> generateUniqueCode() async {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code;
    bool isUnique = false;

    while (!isUnique) {
      code = String.fromCharCodes(Iterable.generate(
          5, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

      // Vérifier si le code existe déjà dans Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uniqueCode', isEqualTo: code)
          .get();

      if (querySnapshot.docs.isEmpty) {
        isUnique = true;
        return code;
      }
    }

    // Cette ligne ne devrait jamais être atteinte, mais Dart l'exige pour la compilation
    throw Exception('Impossible de générer un code unique');
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      String userId = userModel.userId;

      final ref = FirebaseStorage.instance
          .ref()
          .child('user_profile_images')
          .child('$userId.jpg');

      await ref.putFile(_imageFile!);
      final url = await ref.getDownloadURL();

      await userModel.updateUserProfile({'image_profile': url});

      setState(() => _isImageUploaded = true);
    } catch (e) {
      // Afficher une alerte d'erreur
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Erreur'),
          content: const Text(
              'Une erreur est survenue lors du téléchargement de l\'image. Veuillez réessayer.'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ... (les autres méthodes restent inchangées)

  Future<void> _completeProfile() async {
    setState(() => _isLoading = true);
    try {
      final userModel = Provider.of<UserModel>(context, listen: false);

      String firstName = _firstNameController.text.trim();
      String lastName = _lastNameController.text.trim();

      // Générer searchName
      List<String> searchName = generateSearchKeywords('$firstName $lastName');

      String uniqueCode = await generateUniqueCode();

      // Mettre à jour le profil utilisateur
      await userModel.updateUserProfile({
        'firstName': firstName,
        'lastName': lastName,
        'isProfileComplete': true,
        'searchName': searchName,
        'uniqueCode': uniqueCode,
      });

      // Créer un client Stripe
      final FirebaseFunctions functions = FirebaseFunctions.instance;
      final result =
          await functions.httpsCallable('createStripeCustomer').call();

      if (result.data['customerId'] != null) {
        await userModel
            .updateUserProfile({'stripeCustomerId': result.data['customerId']});
      }

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      // Afficher une alerte d'erreur
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: const Text('Erreur'),
          content: const Text(
              'Une erreur est survenue lors de la mise à jour de votre profil. Veuillez réessayer.'),
          actions: <CupertinoDialogAction>[
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
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
}
