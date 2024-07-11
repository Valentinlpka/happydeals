import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;

  bool _isEditing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController(text: _auth.currentUser?.email);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final usersProvider = Provider.of<UserModel>(context, listen: false);
    if (mounted) {
      setState(() {
        _firstNameController.text = usersProvider.firstName;
        _lastNameController.text = usersProvider.lastName;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final usersProvider = Provider.of<UserModel>(context, listen: false);
      await _firestore.collection('users').doc(usersProvider.userId).update({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
      });

      if (_auth.currentUser?.email != _emailController.text) {
        await _auth.currentUser?.updateEmail(_emailController.text);
      }

      usersProvider.updateUserData(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });
    }
  }

  Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isLoading = true);
      try {
        File imageFile = File(image.path);
        final usersProvider = Provider.of<UserModel>(context, listen: false);
        String fileName = '${usersProvider.userId}_profile_picture.jpg';
        Reference storageRef =
            _storage.ref().child('profile_pictures/$fileName');
        UploadTask uploadTask = storageRef.putFile(imageFile);
        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await _firestore.collection('users').doc(usersProvider.userId).update({
          'image_profile': downloadUrl,
        });

        usersProvider.profileUrl = downloadUrl;

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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  _updateProfile();
                } else {
                  _isEditing = true;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<UserModel>(
              builder: (context, usersProvider, child) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _changeProfilePicture,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage:
                                  usersProvider.profileUrl.isNotEmpty
                                      ? NetworkImage(usersProvider.profileUrl)
                                      : const AssetImage(
                                              'assets/default_profile.png')
                                          as ImageProvider,
                            ),
                            const CircleAvatar(
                              backgroundColor: Colors.blue,
                              radius: 20,
                              child:
                                  Icon(Icons.camera_alt, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                          'Prénom', _firstNameController, _isEditing),
                      _buildTextField('Nom', _lastNameController, _isEditing),
                      _buildTextField('Email', _emailController, _isEditing),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _showChangePasswordDialog(context),
                        child: const Text('Changer le mot de passe'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, bool enabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2.0),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue, width: 2.0),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ChangePasswordDialog(),
    );
  }
}

class _ChangePasswordDialog extends StatelessWidget {
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Changer le mot de passe'),
      content: TextField(
        controller: _passwordController,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Nouveau mot de passe',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Confirmer'),
          onPressed: () async {
            try {
              await FirebaseAuth.instance.currentUser
                  ?.updatePassword(_passwordController.text);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Mot de passe mis à jour avec succès')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Erreur lors de la mise à jour du mot de passe: $e')),
              );
            }
          },
        ),
      ],
    );
  }
}
