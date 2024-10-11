import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/marketplace/custom_widget.dart';
import 'package:happy/screens/marketplace/photo_section.dart';

class VehicleForm extends StatefulWidget {
  final GlobalKey<VehicleFormState> formKey = GlobalKey<VehicleFormState>();
  final Ad? existingAd;
  VehicleForm({super.key, this.existingAd});

  @override
  VehicleFormState createState() => VehicleFormState();

  Map<String, dynamic> getFormData() {
    final state = formKey.currentState;
    if (state != null) {
      return state.getFormData();
    }
    return {};
  }
}

class VehicleFormState extends State<VehicleForm> {
  final GlobalKey<PhotoSectionState> _photoSectionKey =
      GlobalKey<PhotoSectionState>();

  String? _selectedVehicleType;
  String? _selectedVehicleCondition;
  String? _selectedFuelType;
  String? _selectedTransmissionType;

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _interiorColorController =
      TextEditingController();
  final TextEditingController _exteriorColorController =
      TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingAd != null) {
      _prePopulateFields();
    }
  }

  void _prePopulateFields() {
    final ad = widget.existingAd!;

    _selectedVehicleType = ad.additionalData['vehicleType'] as String?;
    _locationController.text = ad.additionalData['location'] as String? ?? '';
    _yearController.text = ad.additionalData['year'] as String? ?? '';
    _brandController.text = ad.additionalData['brand'] as String? ?? '';
    _modelController.text = ad.additionalData['model'] as String? ?? '';
    _mileageController.text = ad.additionalData['mileage'] as String? ?? '';
    _priceController.text = ad.price.toString();
    _interiorColorController.text =
        ad.additionalData['interiorColor'] as String? ?? '';
    _exteriorColorController.text =
        ad.additionalData['exteriorColor'] as String? ?? '';
    _selectedVehicleCondition = ad.additionalData['condition'] as String?;
    _selectedFuelType = ad.additionalData['fuelType'] as String?;
    _selectedTransmissionType = ad.additionalData['transmission'] as String?;
    _descriptionController.text = ad.description;

    // Gestion des photos existantes
    if (ad.photos.isNotEmpty) {
      _photoSectionKey.currentState?.setExistingPhotos(ad.photos);
    }

    setState(() {});
  }

  @override
  void dispose() {
    _locationController.dispose();
    _yearController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _mileageController.dispose();
    _priceController.dispose();
    _interiorColorController.dispose();
    _exteriorColorController.dispose();
    _descriptionController.dispose();
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
          Row(
            children: [
              Expanded(
                child: buildDropdown(
                  'Type de véhicule',
                  _selectedVehicleType,
                  ['Voiture', 'Moto', 'Camion', 'Autre'],
                  (value) => setState(() => _selectedVehicleType = value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: buildTextField('Lieu', _locationController)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: buildTextField('Année', _yearController)),
              const SizedBox(width: 16),
              Expanded(child: buildTextField('Marque', _brandController)),
              const SizedBox(width: 16),
              Expanded(child: buildTextField('Modèle', _modelController)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: buildTextField('Kilométrage', _mileageController)),
              const SizedBox(width: 16),
              Expanded(child: buildTextField('Prix', _priceController)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: buildTextField(
                      'Couleur intérieure', _interiorColorController)),
              const SizedBox(width: 16),
              Expanded(
                  child: buildTextField(
                      'Couleur extérieure', _exteriorColorController)),
            ],
          ),
          const SizedBox(height: 16),
          buildDropdown(
            'État du véhicule',
            _selectedVehicleCondition,
            ['Neuf', 'Excellent', 'Très bon', 'Bon', 'Correct', 'À rénover'],
            (value) => setState(() => _selectedVehicleCondition = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: buildDropdown(
                  'Type de carburant',
                  _selectedFuelType,
                  [
                    'Essence',
                    'Diesel',
                    'Électrique',
                    'Hybride',
                    'GPL',
                    'Autre'
                  ],
                  (value) => setState(() => _selectedFuelType = value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: buildDropdown(
                  'Boîte de vitesse',
                  _selectedTransmissionType,
                  ['Manuelle', 'Automatique', 'Semi-automatique'],
                  (value) => setState(() => _selectedTransmissionType = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildTextField('Description', _descriptionController, maxLines: 3),
        ],
      ),
    );
  }

  Map<String, dynamic> getFormData() {
    return {
      'vehicleType': _selectedVehicleType ?? '',
      'location': _locationController.text,
      'year': _yearController.text,
      'brand': _brandController.text,
      'model': _modelController.text,
      'mileage': _mileageController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'interiorColor': _interiorColorController.text,
      'exteriorColor': _exteriorColorController.text,
      'condition': _selectedVehicleCondition ?? '',
      'fuelType': _selectedFuelType ?? '',
      'transmission': _selectedTransmissionType ?? '',
      'description': _descriptionController.text,
      'photos': _photoSectionKey.currentState?.getPhotos() ?? [],
    };
  }
}
