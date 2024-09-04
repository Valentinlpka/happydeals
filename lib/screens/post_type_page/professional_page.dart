import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/post_type_page/job_search_profile_page.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class GeneralProfilePage extends StatefulWidget {
  const GeneralProfilePage({super.key});

  @override
  _GeneralProfilePageState createState() => _GeneralProfilePageState();
}

class _GeneralProfilePageState extends State<GeneralProfilePage> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil général'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<UserModel>(
        builder: (context, userModel, child) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: _buildProfileImage(userModel),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField('Prénom', userModel.firstName,
                        (value) => userModel.firstName = value),
                    _buildTextField('Nom', userModel.lastName,
                        (value) => userModel.lastName = value),
                    _buildTextField('Email', userModel.email,
                        (value) => userModel.email = value),
                    _buildTextField('Téléphone', userModel.phone,
                        (value) => userModel.phone = value),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            userModel.updateUserProfile({
                              'firstName': userModel.firstName,
                              'lastName': userModel.lastName,
                              'email': userModel.email,
                              'phone': userModel.phone,
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Profil mis à jour avec succès')),
                            );
                          }
                        },
                        child: const Text('Enregistrer',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const JobSearchProfilePage()),
                          );
                        },
                        child: const Text(
                            'Configurer mon profil de recherche d\'emploi',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(
      String label, String initialValue, Function(String) onSaved) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Ce champ ne peut pas être vide';
          }
          return null;
        },
        onSaved: (value) => onSaved(value!),
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (kIsWeb) {
        // Web platform
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 10, ratioY: 10),
          uiSettings: [
            WebUiSettings(
              context: context,
            ),
          ],
        );
        if (croppedFile != null) {
          final bytes = await croppedFile.readAsBytes();
          setState(() {
            _imageFile = File.fromRawPath(Uint8List.fromList(bytes));
          });
          await _uploadImage();
        }
      } else {
        // Mobile platforms
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 21, ratioY: 11),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Recadrer la photo',
              toolbarColor: Theme.of(context).primaryColor,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
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
          });
          await _uploadImage();
        }
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      final usersProvider = Provider.of<UserModel>(context, listen: false);
      String fileName = '${usersProvider.userId}_profile_picture.jpg';
      Reference storageRef = _storage.ref().child('profile_pictures/$fileName');
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await usersProvider.updateUserProfile({
        'image_profile': downloadUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Photo de profil mise à jour avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de la mise à jour de la photo: $e')),
      );
    }
  }

  Widget _buildProfileImage(UserModel usersProvider) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CupertinoColors.systemGrey5,
          image: _imageFile != null
              ? DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                )
              : usersProvider.profileUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(usersProvider.profileUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: CupertinoColors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.camera,
            color: CupertinoColors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}
