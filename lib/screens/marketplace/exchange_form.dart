import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/marketplace/custom_widget.dart';
import 'package:happy/screens/marketplace/photo_section.dart';

class ExchangeForm extends StatefulWidget {
  final GlobalKey<ExchangeFormState> formKey = GlobalKey<ExchangeFormState>();
  final Ad? existingAd;
  ExchangeForm({super.key, this.existingAd});

  @override
  ExchangeFormState createState() => ExchangeFormState();

  Map<String, dynamic> getFormData() {
    final state = formKey.currentState;
    if (state != null) {
      return state.getFormData();
    }
    return {};
  }
}

class ExchangeFormState extends State<ExchangeForm> {
  final GlobalKey<PhotoSectionState> _photoSectionKey =
      GlobalKey<PhotoSectionState>();

  String? _selectedExchangeType;
  String? _selectedMeetingPreference;

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _wishController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _availabilityController = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.existingAd != null) {
      _prePopulateFields();
    }
  }

  void _prePopulateFields() {
    final ad = widget.existingAd!;

    // Champs communs
    _selectedExchangeType = ad.additionalData['exchangeType'] ?? '';
    _categoryController.text = ad.additionalData['category'] ?? '';
    _locationController.text = ad.additionalData['location'] ?? '';
    _descriptionController.text = ad.description;
    _wishController.text = ad.additionalData['wishInReturn'] ?? '';

    // Pré-remplissage des champs spécifiques selon le type d'échange
    if (_selectedExchangeType == 'Article') {
      _conditionController.text = ad.additionalData['condition'] ?? '';
      _brandController.text = ad.additionalData['brand'] ?? '';
      _tagsController.text = ad.additionalData['tags'] ?? '';
      _selectedMeetingPreference = ad.additionalData['meetingPreference'] ?? '';
    } else if (_selectedExchangeType == 'Temps et Compétences') {
      _experienceController.text = ad.additionalData['experience'] ?? '';
      _availabilityController.text = ad.additionalData['availability'] ?? '';
    }

    // Gestion des photos
    // Nous supposons que la PhotoSection peut être mise à jour avec les URLs des photos existantes
    if (ad.photos.isNotEmpty) {
      _photoSectionKey.currentState?.setExistingPhotos(ad.photos);
    }

    // Forcer la mise à jour de l'interface utilisateur
    setState(() {});
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _wishController.dispose();
    _conditionController.dispose();
    _brandController.dispose();
    _tagsController.dispose();
    _experienceController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          PhotoSection(key: _photoSectionKey),
          const SizedBox(height: 16),
          buildDropdown(
            'Type d\'échange',
            _selectedExchangeType,
            ['Article', 'Temps et Compétences'],
            (value) {
              setState(() {
                _selectedExchangeType = value;
                // Réinitialiser les champs spécifiques si nécessaire
                if (value == 'Article') {
                  _experienceController.clear();
                  _availabilityController.clear();
                } else {
                  _conditionController.clear();
                  _brandController.clear();
                  _tagsController.clear();
                  _selectedMeetingPreference = null;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          buildTextField('Catégorie', _categoryController),
          const SizedBox(height: 16),
          buildTextField('Lieu', _locationController),
          const SizedBox(height: 16),
          buildTextField('Description', _descriptionController, maxLines: 3),
          const SizedBox(height: 16),
          buildTextField('Ce que j\'aimerais en retour', _wishController,
              maxLines: 2),
          const SizedBox(height: 16),
          if (_selectedExchangeType == 'Article') ...[
            Row(
              children: [
                Expanded(child: buildTextField('État', _conditionController)),
                const SizedBox(width: 16),
                Expanded(child: buildTextField('Marque', _brandController)),
              ],
            ),
            const SizedBox(height: 16),
            buildTextField('Tags de produit', _tagsController),
            const SizedBox(height: 16),
            buildDropdown(
              'Préférence de rencontre',
              _selectedMeetingPreference,
              ['En personne', 'Livraison', 'Les deux'],
              (value) => setState(() => _selectedMeetingPreference = value),
            ),
          ] else if (_selectedExchangeType == 'Temps et Compétences') ...[
            buildTextField('Expérience', _experienceController),
            const SizedBox(height: 16),
            buildTextField('Disponibilité', _availabilityController),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> getFormData() {
    Map<String, dynamic> data = {
      'exchangeType': _selectedExchangeType ?? '',
      'category': _categoryController.text,
      'location': _locationController.text,
      'description': _descriptionController.text,
      'wishInReturn': _wishController.text,
      'photos': _photoSectionKey.currentState?.getPhotos() ?? [],
    };

    if (_selectedExchangeType == 'Article') {
      data.addAll({
        'condition': _conditionController.text,
        'brand': _brandController.text,
        'tags': _tagsController.text,
        'meetingPreference': _selectedMeetingPreference ?? '',
      });
    } else if (_selectedExchangeType == 'Temps et Compétences') {
      data.addAll({
        'experience': _experienceController.text,
        'availability': _availabilityController.text,
      });
    }

    return data;
  }
}
