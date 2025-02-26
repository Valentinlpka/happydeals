import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
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

  final List<String> _exchangeTypes = ['Article', 'Temps et Compétences'];
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

  @override
  void initState() {
    super.initState();
    _selectedExchangeType = _exchangeTypes[0];
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
    _titleController.text = ad.title;

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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildSectionTitle('Photos', icon: Icons.photo_camera),
              const SizedBox(height: 8),
              PhotoSection(key: _photoSectionKey),
              const SizedBox(height: 24),
              _buildSectionTitle('Informations générales',
                  icon: Icons.info_outline),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Type d\'échange',
                _selectedExchangeType,
                _exchangeTypes,
                (value) {
                  setState(() {
                    _selectedExchangeType = value;
                    if (value == 'Article') {
                      _experienceController.clear();
                      _availabilityController.clear();
                      _conditionController.text = _conditions[0];
                      _selectedMeetingPreference = _meetingPreferences[0];
                    } else {
                      _conditionController.clear();
                      _brandController.clear();
                      _tagsController.clear();
                      _selectedMeetingPreference = null;
                    }
                  });
                },
                icon: Icons.swap_horiz,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Titre de l\'annonce',
                _titleController,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                icon: Icons.title,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Catégorie',
                _categoryController,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                icon: Icons.category,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Localisation',
                _locationController,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                icon: Icons.location_on,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Description', icon: Icons.description),
              const SizedBox(height: 16),
              _buildTextField(
                'Description détaillée',
                _descriptionController,
                maxLines: 4,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                hint: 'Décrivez en détail ce que vous proposez...',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                'Ce que vous recherchez en échange',
                _wishController,
                maxLines: 3,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                hint: 'Décrivez ce que vous souhaitez obtenir en échange...',
                icon: Icons.swap_horiz,
              ),
              const SizedBox(height: 24),
              if (_selectedExchangeType == 'Article') ...[
                _buildSectionTitle('Détails de l\'article',
                    icon: Icons.inventory_2),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'État',
                  _conditionController.text.isEmpty
                      ? _conditions[0]
                      : _conditionController.text,
                  _conditions,
                  (value) => setState(() =>
                      _conditionController.text = value ?? _conditions[0]),
                  icon: Icons.star_border,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Marque',
                  _brandController,
                  icon: Icons.business,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Mots-clés',
                  _tagsController,
                  hint: 'Séparez les mots-clés par des virgules',
                  icon: Icons.tag,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  'Préférence de rencontre',
                  _selectedMeetingPreference ?? _meetingPreferences[0],
                  _meetingPreferences,
                  (value) => setState(() => _selectedMeetingPreference = value),
                  icon: Icons.handshake,
                ),
              ],
              if (_selectedExchangeType == 'Temps et Compétences') ...[
                _buildSectionTitle('Détails du service',
                    icon: Icons.engineering),
                const SizedBox(height: 16),
                _buildTextField(
                  'Expérience',
                  _experienceController,
                  maxLines: 3,
                  hint: 'Décrivez votre expérience dans ce domaine...',
                  icon: Icons.work,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  'Disponibilité',
                  _availabilityController,
                  hint: 'Ex: Soirs et weekends',
                  icon: Icons.access_time,
                ),
              ],
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
          Icon(icon, color: Colors.blue[700], size: 24),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    void Function(String?) onChanged, {
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value ?? items[0],
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          onChanged(newValue);
        });
      },
      validator: (value) => value == null ? 'Ce champ est requis' : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
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
