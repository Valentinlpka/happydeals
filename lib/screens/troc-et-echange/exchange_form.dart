import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/troc-et-echange/city_autocomplete.dart';
import 'package:happy/screens/troc-et-echange/photo_section.dart';

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
  final _formKey = GlobalKey<FormState>();

  String? _selectedExchangeType;
  String? _selectedMeetingPreference;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _wishController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _availabilityController = TextEditingController();

  final List<String> _exchangeTypes = ['Article'];
  final List<String> _meetingPreferences = [
    'En personne',
    'Livraison',
    'Les deux'
  ];
  final List<String> _conditions = [
    'Neuf',
    'Très bon état',
    'Bon état',
    'État moyen',
    'À rénover'
  ];

  Map<String, dynamic>? _selectedCityData;

  @override
  void initState() {
    super.initState();
    _selectedExchangeType = _exchangeTypes[0];
    _selectedMeetingPreference = _meetingPreferences[0];
    if (widget.existingAd != null) {
      _prePopulateFields();
    }
  }

  void _prePopulateFields() {
    final ad = widget.existingAd!;

    // Champs communs
    final exchangeType = ad.additionalData['exchangeType'] ?? '';
    _selectedExchangeType = _exchangeTypes.contains(exchangeType)
        ? exchangeType
        : _exchangeTypes[0];

    _categoryController.text = ad.additionalData['category'] ?? '';
    _locationController.text = ad.additionalData['location'] ?? '';
    _descriptionController.text = ad.description;
    _wishController.text = ad.additionalData['wishInReturn'] ?? '';
    _titleController.text = ad.title;

    // Pré-remplissage des champs spécifiques selon le type d'échange
    if (_selectedExchangeType == 'Article') {
      _conditionController.text =
          ad.additionalData['condition'] ?? _conditions[0];
      _brandController.text = ad.additionalData['brand'] ?? '';
      _tagsController.text = ad.additionalData['tags'] ?? '';
      final meetingPref = ad.additionalData['meetingPreference'] ?? '';
      _selectedMeetingPreference = _meetingPreferences.contains(meetingPref)
          ? meetingPref
          : _meetingPreferences[0];
    } else if (_selectedExchangeType == 'Temps et Compétences') {
      _experienceController.text = ad.additionalData['experience'] ?? '';
      _availabilityController.text = ad.additionalData['availability'] ?? '';
    }

    // Gestion des photos existantes
    if (ad.photos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_photoSectionKey.currentState != null) {
          _photoSectionKey.currentState!.setExistingPhotos(ad.photos);
        }
      });
    }

    // Données de localisation
    if (ad.additionalData['coordinates'] != null) {
      _selectedCityData = {
        'coordinates': ad.additionalData['coordinates'],
        'name': ad.additionalData['cityName'] ?? '',
        'fullName': ad.additionalData['fullAddress'] ?? '',
      };
    }

    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildSectionTitle('Photos', icon: Icons.photo_camera),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Ajoutez jusqu\'à 5 photos de votre objet',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: PhotoSection(key: _photoSectionKey),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Informations générales',
                  icon: Icons.info_outline),
              const SizedBox(height: 24),
              _buildTextField(
                'Titre de l\'annonce',
                _titleController,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                icon: Icons.title,
                hint: 'Ex: Vélo VTT contre Guitare acoustique',
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Catégorie',
                _categoryController,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                icon: Icons.category,
                hint: 'Ex: Sport & Loisirs',
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Localisation',
                _locationController,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                icon: Icons.location_on,
                hint: 'Saisissez votre ville',
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Description', icon: Icons.description),
              const SizedBox(height: 24),
              _buildTextField(
                'Description détaillée',
                _descriptionController,
                maxLines: 4,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                hint: 'Décrivez en détail ce que vous proposez...',
                backgroundColor: Colors.grey[50],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Ce que vous recherchez en échange',
                _wishController,
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                hint: 'Décrivez ce que vous souhaitez obtenir en échange...',
                icon: Icons.swap_horiz,
                backgroundColor: Colors.grey[50],
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Détails de l\'objet',
                  icon: Icons.inventory_2),
              const SizedBox(height: 24),
              _buildDropdownField(
                'État',
                _conditionController.text.isEmpty
                    ? _conditions[0]
                    : _conditionController.text,
                _conditions,
                (value) => setState(
                    () => _conditionController.text = value ?? _conditions[0]),
                icon: Icons.star_border,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Marque',
                _brandController,
                icon: Icons.business,
                hint: 'Ex: Decathlon, Samsung, Apple...',
              ),
              const SizedBox(height: 20),
              _buildTextField(
                'Mots-clés',
                _tagsController,
                hint: 'Séparez les mots-clés par des virgules',
                icon: Icons.tag,
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                'Préférence de rencontre',
                _selectedMeetingPreference ?? _meetingPreferences[0],
                _meetingPreferences,
                (value) => setState(() => _selectedMeetingPreference = value),
                icon: Icons.handshake,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.grey[800], size: 22),
          const SizedBox(width: 12),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[900],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
    IconData? icon,
    String? Function(String?)? validator,
    Color? backgroundColor,
  }) {
    if (label == 'Localisation') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ville',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          CityAutocomplete(
            controller: controller,
            onCitySelected: (cityData) {
              setState(() {
                _selectedCityData = cityData;
              });
            },
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: icon != null
                  ? Icon(icon, color: Colors.grey[600], size: 20)
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              filled: true,
              fillColor: backgroundColor ?? Colors.white,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    void Function(String?) onChanged, {
    IconData? icon,
  }) {
    final effectiveValue = items.contains(value) ? value : items[0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonFormField<String>(
            value: effectiveValue,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                onChanged(newValue);
              });
            },
            validator: (value) => value == null ? 'Ce champ est requis' : null,
            decoration: InputDecoration(
              prefixIcon: icon != null
                  ? Icon(icon, color: Colors.grey[600], size: 20)
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              filled: true,
              fillColor: Colors.white,
            ),
            dropdownColor: Colors.white,
            icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> getFormData() {
    Map<String, dynamic> data = {
      'title': _titleController.text,
      'exchangeType': _selectedExchangeType ?? '',
      'category': _categoryController.text,
      'location': _locationController.text,
      'description': _descriptionController.text,
      'wishInReturn': _wishController.text,
      'photos': _photoSectionKey.currentState?.getPhotos() ?? [],
    };

    if (_selectedCityData != null) {
      final coordinates = _selectedCityData!['coordinates'] as List<dynamic>;
      data.addAll({
        'coordinates': coordinates,
        'cityName': _selectedCityData!['name'],
        'fullAddress': _selectedCityData!['fullName'],
        'latitude': coordinates[1],
        'longitude': coordinates[0],
      });
    }

    if (_selectedExchangeType == 'Article') {
      data.addAll({
        'condition': _conditionController.text.isNotEmpty
            ? _conditionController.text
            : _conditions[0],
        'brand': _brandController.text,
        'tags': _tagsController.text,
        'meetingPreference':
            _selectedMeetingPreference ?? _meetingPreferences[0],
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
