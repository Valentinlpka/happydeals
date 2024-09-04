import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfileImagePicker extends StatefulWidget {
  final String currentImageUrl;

  const ProfileImagePicker({super.key, required this.currentImageUrl});

  @override
  _ProfileImagePickerState createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  File? _imageFile;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      String fileName = '${userModel.userId}_profile_picture.jpg';
      Reference storageRef = _storage.ref().child('profile_pictures/$fileName');
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await userModel.updateUserProfile({'profileUrl': downloadUrl});

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickImage,
      child: CircleAvatar(
        radius: 60,
        backgroundImage: _imageFile != null
            ? FileImage(_imageFile!)
            : NetworkImage(widget.currentImageUrl) as ImageProvider,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              radius: 20,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
