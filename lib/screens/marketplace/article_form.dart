import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/marketplace/custom_widget.dart';
import 'package:happy/screens/marketplace/photo_section.dart';

class ArticleForm extends StatefulWidget {
  final GlobalKey<ArticleFormState> formKey = GlobalKey<ArticleFormState>();
  final Ad? existingAd;

  ArticleForm({super.key, this.existingAd});

  @override
  ArticleFormState createState() => ArticleFormState();

  Map<String, dynamic> getFormData() {
    final state = formKey.currentState;
    if (state != null) {
      return state.getFormData();
    }
    return {};
  }
}

class ArticleFormState extends State<ArticleForm> {
  @override
  void initState() {
    super.initState();
    if (widget.existingAd != null) {
      _prePopulateFields();
    }
  }

  void _prePopulateFields() {
    final ad = widget.existingAd!;

    // Champs principaux
    _titleController.text = ad.title;
    _priceController.text = ad.price.toString();
    _descriptionController.text = ad.description;

    // Champs dans additionalData
    selectedCategory = ad.additionalData['category'] as String?;
    selectedState = ad.additionalData['condition'] as String?;
    _brandController.text = ad.additionalData['brand'] as String? ?? '';
    _tagsController.text = ad.additionalData['tags'] as String? ?? '';
    _locationController.text = ad.additionalData['location'] as String? ?? '';
    selectedMeetingPreference =
        ad.additionalData['meetingPreference'] as String?;

    // Gestion des photos existantes
    if (ad.photos.isNotEmpty) {
      _photoSectionKey.currentState?.setExistingPhotos(ad.photos);
    }

    // Forcer la mise à jour de l'interface utilisateur
    setState(() {});
  }

  final GlobalKey<PhotoSectionState> _photoSectionKey =
      GlobalKey<PhotoSectionState>();

  String? selectedCategory;
  String? selectedState;
  String? selectedMeetingPreference;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _locationController.dispose();
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
          buildTextField('Titre', _titleController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: buildTextField('Prix', _priceController)),
              const SizedBox(width: 16),
              Expanded(
                child: buildDropdown(
                  'Catégorie',
                  selectedCategory,
                  ['Électronique', 'Vêtements', 'Maison', 'Autre'],
                  (value) => setState(() => selectedCategory = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: buildDropdown(
                  'État',
                  selectedState,
                  [
                    'Neuf',
                    'Très bon état',
                    'Bon état',
                    'Satisfaisant',
                    'À rénover'
                  ],
                  (value) => setState(() => selectedState = value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: buildTextField('Marque', _brandController)),
            ],
          ),
          const SizedBox(height: 16),
          buildTextField('Description', _descriptionController, maxLines: 3),
          const SizedBox(height: 16),
          buildTextField('Tags de produit', _tagsController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: buildTextField('Lieu', _locationController)),
              const SizedBox(width: 16),
              Expanded(
                child: buildDropdown(
                  'Préférence de rencontre',
                  selectedMeetingPreference,
                  ['En personne', 'Livraison', 'Les deux'],
                  (value) => setState(() => selectedMeetingPreference = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> getFormData() {
    return {
      'title': _titleController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'category': selectedCategory ?? '',
      'condition': selectedState ?? '',
      'brand': _brandController.text,
      'description': _descriptionController.text,
      'tags': _tagsController.text,
      'location': _locationController.text,
      'meetingPreference': selectedMeetingPreference ?? '',
      'photos': _photoSectionKey.currentState?.getPhotos() ?? [],
    };
  }
}
