import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/marketplace/city_autocomplete.dart';
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
  void initState() {
    super.initState();
    if (widget.existingAd != null) {
      _prePopulateFields();
    }
  }

  void _prePopulateFields() {
    final ad = widget.existingAd!;

    _titleController.text = ad.title;
    _priceController.text = ad.price.toString();
    _descriptionController.text = ad.description;
    _brandController.text = ad.additionalData['brand'] as String? ?? '';
    _tagsController.text = ad.additionalData['tags'] as String? ?? '';
    _locationController.text = ad.additionalData['location'] as String? ?? '';

    selectedCategory = ad.additionalData['category'] as String?;
    selectedState = ad.additionalData['condition'] as String?;
    selectedMeetingPreference =
        ad.additionalData['meetingPreference'] as String?;

    if (ad.photos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _photoSectionKey.currentState?.setExistingPhotos(ad.photos);
      });
    }

    setState(
        () {}); // Cette ligne est nécessaire pour mettre à jour les dropdowns
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
                child: StatefulBuilder(
                  builder:
                      (BuildContext context, StateSetter setDropdownState) {
                    return buildDropdown(
                      'Catégorie',
                      selectedCategory,
                      ['Électronique', 'Vêtements', 'Maison', 'Autre'],
                      (value) =>
                          setDropdownState(() => selectedCategory = value),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatefulBuilder(
                  builder:
                      (BuildContext context, StateSetter setDropdownState) {
                    return buildDropdown(
                      'État',
                      selectedState,
                      [
                        'Neuf',
                        'Très bon état',
                        'Bon état',
                        'Satisfaisant',
                        'À rénover'
                      ],
                      (value) => setDropdownState(() => selectedState = value),
                    );
                  },
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
              Expanded(
                child: buildCityTextField('Lieu', _locationController),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatefulBuilder(
                  builder:
                      (BuildContext context, StateSetter setDropdownState) {
                    return buildDropdown(
                      'Préférence de rencontre',
                      selectedMeetingPreference,
                      ['En personne', 'Livraison', 'Les deux'],
                      (value) => setDropdownState(
                          () => selectedMeetingPreference = value),
                    );
                  },
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
