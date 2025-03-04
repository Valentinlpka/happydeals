import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/post_type_page/job_search_profile_page.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class City {
  final String inseeCode;
  final String label;
  final String zipCode;
  final double latitude;
  final double longitude;

  City({
    required this.inseeCode,
    required this.label,
    required this.zipCode,
    required this.latitude,
    required this.longitude,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    String capitalizeWords(String input) {
      if (input.isEmpty) return input;
      return input.split(' ').map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }

    double parseCoordinate(String value) {
      try {
        return double.parse(value.trim());
      } catch (e) {
        print('Erreur de conversion pour la coordonnée: $value');
        return 0.0;
      }
    }

    return City(
      inseeCode: json['insee_code'] as String,
      label: capitalizeWords(json['label'] as String),
      zipCode: json['zip_code'] as String,
      latitude: parseCoordinate(json['latitude'] as String),
      longitude: parseCoordinate(json['longitude'] as String),
    );
  }
}

class GeneralProfilePage extends StatefulWidget {
  const GeneralProfilePage({super.key});

  @override
  _GeneralProfilePageState createState() => _GeneralProfilePageState();
}

class _GeneralProfilePageState extends State<GeneralProfilePage> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _formKey = GlobalKey<FormState>();
  dynamic _imageFile;
  List<City> _allCities = [];
  List<City> _filteredCities = [];
  final TextEditingController _cityController = TextEditingController();
  bool _isLoadingCities = false;
  City? _selectedCity;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      setState(() {
        _isLoadingCities = true;
      });

      final String jsonString =
          await rootBundle.loadString('assets/french_cities.json');
      final data = json.decode(jsonString);

      _allCities = (data['cities'] as List)
          .map((cityJson) => City.fromJson(cityJson))
          .toList();

      setState(() {
        _isLoadingCities = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des villes: $e');
      setState(() {
        _isLoadingCities = false;
      });
    }
  }

  void _filterCities(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredCities = [];
      });
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
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBarBack(
        title: 'Profil général',
      ),
      body: Consumer<UserModel>(
        builder: (context, userModel, child) {
          return SingleChildScrollView(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Photo de profil'),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: _buildProfileImage(userModel),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Informations personnelles'),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTextField('Prénom', userModel.firstName,
                                (value) => userModel.firstName = value),
                            _buildTextField('Nom', userModel.lastName,
                                (value) => userModel.lastName = value),
                            _buildTextField('Ville', userModel.city,
                                (value) => userModel.city = value,
                                controller: _cityController),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Coordonnées'),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildTextField('Email', userModel.email,
                                (value) => userModel.email = value),
                            _buildTextField('Téléphone', userModel.phone,
                                (value) => userModel.phone = value),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            userModel.updateUserProfile({
                              'firstName': userModel.firstName,
                              'lastName': userModel.lastName,
                              'email': userModel.email,
                              'phone': userModel.phone,
                              'city': userModel.city,
                              'zipCode': userModel.zipCode,
                              'latitude': userModel.latitude,
                              'longitude': userModel.longitude,
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Profil mis à jour avec succès')),
                            );
                          }
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Enregistrer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.check_circle_outline, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const JobSearchProfilePage()),
                          );
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          leading: Icon(
                            Icons.work_outline,
                            color: Colors.blue[700],
                          ),
                          title: const Text(
                            'Profil de recherche d\'emploi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label, String initialValue, Function(String) onSaved,
      {TextEditingController? controller}) {
    if (label == 'Ville') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'Ville',
              hintText: 'Entrez votre ville',
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
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
              ),
            ),
            onChanged: (value) {
              _filterCities(value);
              setState(() {
                _selectedCity = null;
              });
            },
          ),
          if (_filteredCities.isNotEmpty && _selectedCity == null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
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
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCity = city;
                          _cityController.text =
                              '${city.label} (${city.zipCode})';
                          _filteredCities = [];
                        });
                        Provider.of<UserModel>(context, listen: false)
                          ..city = city.label
                          ..zipCode = city.zipCode
                          ..latitude = city.latitude
                          ..longitude = city.longitude;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          '${city.label} (${city.zipCode})',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          decoration: InputDecoration(
            hintText: 'Entrez votre $label',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(
              _getIconForField(label),
              color: Colors.grey[600],
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red[300]!, width: 1),
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ce champ ne peut pas être vide';
            }
            return null;
          },
          onSaved: (value) => onSaved(value!),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  IconData _getIconForField(String label) {
    switch (label.toLowerCase()) {
      case 'prénom':
        return Icons.person_outline;
      case 'nom':
        return Icons.person_outline;
      case 'email':
        return Icons.email_outlined;
      case 'téléphone':
        return Icons.phone_outlined;
      case 'ville':
        return Icons.location_city;
      default:
        return Icons.edit_outlined;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (kIsWeb) {
        // Web platform
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
          setState(() {
            _imageFile = Uint8List.fromList(bytes);
          });
          await _uploadImage();
        }
      } else {
        // Mobile platforms
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

      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(_imageFile);
      } else {
        uploadTask = storageRef.putFile(_imageFile);
      }

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
                  image: kIsWeb
                      ? MemoryImage(_imageFile)
                      : FileImage(_imageFile) as ImageProvider,
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
            Icons.camera,
            color: CupertinoColors.white,
            size: 40,
          ),
        ),
      ),
    );
  }
}
