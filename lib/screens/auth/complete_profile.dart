import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/main_container.dart';
import 'package:happy/screens/post_type_page/professional_page.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfileCompletionPage extends StatefulWidget {
  const ProfileCompletionPage({super.key});

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = false;
  dynamic _imageFile;
  bool _isImageUploaded = false;
  List<City> _allCities = [];
  List<City> _filteredCities = [];
  City? _selectedCity;
  bool _showEmail = false;
  bool _showPhone = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    _firstNameController.text = userModel.firstName;
    _lastNameController.text = userModel.lastName;
    _emailController.text = userModel.email;
    _phoneController.text = userModel.phone;
    _cityController.text = userModel.city;
    setState(() {
      _showEmail = userModel.showEmail;
      _showPhone = userModel.showPhone;
    });
  }

  Future<void> _loadCities() async {
    try {
      setState(() => _isLoading = true);
      final String jsonString =
          await rootBundle.loadString('assets/french_cities.json');
      final data = json.decode(jsonString);
      _allCities = (data['cities'] as List)
          .map((cityJson) => City.fromJson(cityJson))
          .toList();
    } catch (e) {
      debugPrint('Erreur lors du chargement des villes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterCities(String query) {
    if (query.isEmpty) {
      setState(() => _filteredCities = []);
      return;
    }
    setState(() {
      _filteredCities = _allCities
          .where((city) =>
              city.label.toLowerCase().contains(query.toLowerCase()) ||
              city.zipCode.contains(query))
          .take(5)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complétez votre profil',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3799),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ces informations nous permettront de mieux vous connaître',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                Center(child: _buildProfileImage()),
                const SizedBox(height: 32),
                _buildInputSection(
                  title: 'Informations personnelles',
                  children: [
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'Prénom',
                      icon: Icons.person_outline,
                    ),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Nom',
                      icon: Icons.person_outline,
                    ),
                    _buildCityField(),
                  ],
                ),
                const SizedBox(height: 24),
                _buildInputSection(
                  title: 'Coordonnées',
                  children: [
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      suffix: Switch(
                        value: _showEmail,
                        onChanged: (value) =>
                            setState(() => _showEmail = value),
                      ),
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Téléphone',
                      icon: Icons.phone_outlined,
                      suffix: Switch(
                        value: _showPhone,
                        onChanged: (value) =>
                            setState(() => _showPhone = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3799),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Terminer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          suffixIcon: suffix,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3799), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildCityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cityController,
          decoration: InputDecoration(
            labelText: 'Ville',
            prefixIcon: Icon(Icons.location_city, color: Colors.grey[600]),
            suffixIcon: _selectedCity != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _selectedCity = null;
                        _cityController.clear();
                        _filteredCities = [];
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          onChanged: _filterCities,
        ),
        if (_filteredCities.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(26),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _filteredCities.length,
              itemBuilder: (context, index) {
                final city = _filteredCities[index];
                return ListTile(
                  title: Text('${city.label} (${city.zipCode})'),
                  onTap: () {
                    setState(() {
                      _selectedCity = city;
                      _cityController.text = '${city.label} (${city.zipCode})';
                      _filteredCities = [];
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
          image: _imageFile != null
              ? DecorationImage(
                  image: kIsWeb
                      ? MemoryImage(_imageFile as Uint8List)
                      : FileImage(_imageFile as File) as ImageProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _isImageUploaded
                ? Colors.green.withAlpha(70)
                : Colors.black.withAlpha(50),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isImageUploaded ? Icons.check : Icons.camera_alt,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Future<void> _completeProfile() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Veuillez remplir tous les champs obligatoires')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      String uniqueCode = await generateUniqueCode();

      await userModel.updateUserProfile({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'city': _selectedCity?.label ?? '',
        'zipCode': _selectedCity?.zipCode ?? '',
        'latitude': _selectedCity?.latitude ?? 0.0,
        'longitude': _selectedCity?.longitude ?? 0.0,
        'showEmail': _showEmail,
        'showPhone': _showPhone,
        'isProfileComplete': true,
        'uniqueCode': uniqueCode,
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainContainer()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur lors de la mise à jour du profil: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uniqueCode', isEqualTo: code)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return code;
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (kIsWeb) {
        if (!mounted) return;
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            WebUiSettings(
              context: context,
            ),
          ],
        );
        if (croppedFile != null) {
          final bytes = await croppedFile.readAsBytes();
          if (!mounted) return;
          setState(() {
            _imageFile = bytes;
            _isImageUploaded = false;
          });
          await _uploadImage();
        }
      } else {
        if (!mounted) return;
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
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
          if (!mounted) return;
          setState(() {
            _imageFile = File(croppedFile.path);
            _isImageUploaded = false;
          });
          await _uploadImage();
        }
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      String fileName = '${userModel.userId}_profile_picture.jpg';
      Reference storageRef = _storage.ref().child('profile_pictures/$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(_imageFile);
      } else {
        uploadTask = storageRef.putFile(_imageFile);
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await userModel.updateUserProfile({
        'image_profile': downloadUrl,
      });

      if (mounted) {
        setState(() => _isImageUploaded = true);
      }
    } catch (e) {
      if (mounted) {
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
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
