import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  bool _isEditing = false;
  bool _isLoading = true;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final usersProvider = Provider.of<UserModel>(context, listen: false);
    await usersProvider.loadUserData();
    if (mounted) {
      setState(() {
        _firstNameController.text = usersProvider.firstName;
        _lastNameController.text = usersProvider.lastName;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemBackground,
      appBar: AppBar(
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(
              _isEditing ? Icons.save_outlined : Icons.edit_outlined,
              color: CupertinoColors.activeBlue,
            ),
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
        title: const Text('Mon Profil'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Consumer<UserModel>(
              builder: (context, usersProvider, child) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildProfileImage(usersProvider),
                      const SizedBox(height: 32),
                      _buildInputField(
                        controller: _firstNameController,
                        placeholder: 'Prénom',
                        enabled: _isEditing,
                      ),
                      const SizedBox(height: 16),
                      _buildInputField(
                        controller: _lastNameController,
                        placeholder: 'Nom',
                        enabled: _isEditing,
                      ),
                      const SizedBox(height: 32),
                      _buildChangePasswordButton(),
                      const SizedBox(height: 16),
                      _buildSignOutButton(),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildProfileImage(UserModel usersProvider) {
    return GestureDetector(
      onTap: _isEditing ? _pickImage : null,
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
        child: _isEditing
            ? Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.camera,
                  color: CupertinoColors.white,
                  size: 40,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String placeholder,
    required bool enabled,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      enabled: enabled,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: enabled
            ? CupertinoColors.extraLightBackgroundGray
            : CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: enabled
              ? CupertinoColors.systemGrey4
              : CupertinoColors.systemGrey3,
        ),
      ),
      style: const TextStyle(fontSize: 17),
      placeholderStyle: TextStyle(
        color: enabled
            ? CupertinoColors.placeholderText
            : CupertinoColors.inactiveGray,
        fontSize: 17,
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildChangePasswordButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        onPressed: () => _showChangePasswordDialog(context),
        color: CupertinoColors.systemGrey5,
        borderRadius: BorderRadius.circular(8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: const Text(
          'Changer le mot de passe',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.activeBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        onPressed: _signOut,
        color: CupertinoColors.destructiveRed,
        borderRadius: BorderRadius.circular(8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: const Text(
          'Se déconnecter',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.white,
          ),
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
        });
        await _uploadImage();
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);

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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final usersProvider = Provider.of<UserModel>(context, listen: false);
      await usersProvider.updateUserProfile({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour avec succès')),
      );
      setState(() => _isEditing = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => _ChangePasswordDialog(),
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Provider.of<UserModel>(context, listen: false).clearUserData();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
      );
    }
  }
}

class _ChangePasswordDialog extends StatelessWidget {
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Changer le mot de passe'),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: CupertinoTextField(
          controller: _passwordController,
          obscureText: true,
          placeholder: 'Nouveau mot de passe',
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CupertinoColors.systemGrey4),
          ),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        CupertinoDialogAction(
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
