import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:happy/widgets/pdf_viewer_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class JobSearchProfilePage extends StatefulWidget {
  const JobSearchProfilePage({super.key});

  @override
  _JobSearchProfilePageState createState() => _JobSearchProfilePageState();
}

class _JobSearchProfilePageState extends State<JobSearchProfilePage> {
  final _formKey = GlobalKey<FormState>();
  String? _cvFileName;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final List<String> _industrySectors = [
    'Agriculture et agroalimentaire',
    'Architecture et urbanisme',
    'Arts, culture et divertissement',
    'Assurance',
    'Automobile',
    'Banque et services financiers',
    'Bâtiment et travaux publics',
    'Biotechnologie',
    'Commerce de détail',
    'Commerce de gros',
    'Communication et médias',
    'Conseil et audit',
    'Défense et aérospatiale',
    'Éducation et formation',
    'Énergie et ressources naturelles',
    'Environnement et développement durable',
    'Fabrication et production',
    'Hôtellerie et restauration',
    'Immobilier',
    'Industrie pharmaceutique',
    "Informatique et technologies de l'information",
    'Ingénierie',
    'Logistique et transport',
    'Marketing et publicité',
    'Mode et textile',
    'ONG et associations',
    'Recherche et développement',
    'Recrutement et ressources humaines',
    'Santé et services sociaux',
    'Sécurité et services de protection',
    'Services aux entreprises',
    'Services juridiques',
    'Services publics et administration',
    'Sport et loisirs',
    'Télécommunications',
    'Tourisme et voyages',
    'Traduction et interprétation',
  ];

  List<Experience> _experiences = [];
  List<Formation> _formations = [];
  List<Competence> _competences = [];

  List<Experience> _tempExperiences = [];
  List<Formation> _tempFormations = [];
  List<Competence> _tempCompetences = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR');
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (!userDoc.exists) return;

    final userData = userDoc.data()!;

    setState(() {
      _experiences = (userData['experiences'] as List? ?? [])
          .map((e) => Experience.fromMap(e))
          .toList()
        ..sort((a, b) => a.ordre.compareTo(b.ordre));

      _formations = (userData['formations'] as List? ?? [])
          .map((e) => Formation.fromMap(e))
          .toList()
        ..sort((a, b) => a.ordre.compareTo(b.ordre));

      _competences = (userData['competences'] as List? ?? [])
          .map((e) => Competence.fromMap(e))
          .toList()
        ..sort((a, b) => a.ordre.compareTo(b.ordre));

      _tempExperiences = List.from(_experiences);
      _tempFormations = List.from(_formations);
      _tempCompetences = List.from(_competences);
    });
  }

  void _saveData() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'searchJobActive': true,
            'showEmail':
                Provider.of<UserModel>(context, listen: false).showEmail,
            'showPhone':
                Provider.of<UserModel>(context, listen: false).showPhone,
            'desiredPosition':
                Provider.of<UserModel>(context, listen: false).desiredPosition,
            'description':
                Provider.of<UserModel>(context, listen: false).description,
            'availability':
                Provider.of<UserModel>(context, listen: false).availability,
            'availabilityDate':
                Provider.of<UserModel>(context, listen: false).availability ==
                        'Date précise'
                    ? Provider.of<UserModel>(context, listen: false)
                        .availabilityDate
                    : null,
            'contractTypes':
                Provider.of<UserModel>(context, listen: false).contractTypes,
            'workingHours':
                Provider.of<UserModel>(context, listen: false).workingHours,
            'industrySector':
                Provider.of<UserModel>(context, listen: false).industrySector,
            'experiences': _tempExperiences.map((e) => e.toMap()).toList(),
            'formations': _tempFormations.map((f) => f.toMap()).toList(),
            'competences': _tempCompetences.map((c) => c.toMap()).toList(),
            'timestampProfile': Timestamp.fromDate(DateTime.now()),
          }, SetOptions(merge: true));

          setState(() {
            _experiences = List.from(_tempExperiences);
            _formations = List.from(_tempFormations);
            _competences = List.from(_tempCompetences);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Profil de recherche d\'emploi mis à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la sauvegarde: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 15,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              elevation: 0,
            ),
            onPressed: _saveData,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
      ),
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBarBack(
        title: 'Profil de recherche d\'emploi',
      ),
      body: Consumer<UserModel>(
        builder: (context, userModel, child) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 24.0,
                  bottom:
                      100.0, // Ajouter du padding en bas pour éviter que le contenu soit caché par le bouton
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Informations de contact'),
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
                              _buildSwitchTile(
                                  'Partager l\'email',
                                  userModel.showEmail,
                                  (value) => userModel.showEmail = value),
                              _buildSwitchTile(
                                  'Partager le téléphone',
                                  userModel.showPhone,
                                  (value) => userModel.showPhone = value),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Informations professionnelles'),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(
                                  'Poste recherché',
                                  userModel.desiredPosition,
                                  (value) => userModel.desiredPosition = value),
                              const SizedBox(height: 24),
                              _buildDropdownField(
                                  'Secteur d\'activité',
                                  userModel.industrySector,
                                  (value) => userModel.industrySector = value!,
                                  _industrySectors),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('CV et présentation'),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCVUpload(userModel),
                              const SizedBox(height: 24),
                              _buildTextField(
                                  'Description',
                                  userModel.description,
                                  (value) => userModel.description = value,
                                  maxLines: 3,
                                  hintText:
                                      'Décrivez votre profil et vos objectifs professionnels...'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionTitle('Préférences de travail'),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDropdownField(
                                  'Disponibilité',
                                  userModel.availability,
                                  (value) => userModel.availability = value!, [
                                'Tout de suite',
                                'Date précise',
                                'À définir'
                              ]),
                              if (userModel.availability == 'Date précise')
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: _buildDatePicker(
                                    label: 'Date de disponibilité',
                                    selectedDate: userModel.availabilityDate,
                                    onChanged: (date) => setState(() =>
                                        userModel.availabilityDate = date),
                                    minDate: DateTime.now(),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              _buildContractTypes(userModel),
                              const SizedBox(height: 24),
                              _buildDropdownField(
                                  'Horaire',
                                  userModel.workingHours,
                                  (value) => userModel.workingHours = value!,
                                  ['Mi-temps', 'Temps plein', 'Temps partiel']),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildExperiencesList(),
                      const SizedBox(height: 24),
                      _buildFormationsList(),
                      const SizedBox(height: 24),
                      _buildCompetencesList(),
                    ],
                  ),
                ),
              ),
            ],
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

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue[700],
      activeTrackColor: Colors.blue[100],
      inactiveThumbColor: Colors.grey[400],
      inactiveTrackColor: Colors.grey[200],
    );
  }

  Widget _buildTextField(
      String label, String initialValue, Function(String) onSaved,
      {int maxLines = 1, String? hintText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400]),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            prefixIcon: Icon(
              _getIconForField(label),
              color: Colors.grey[600],
            ),
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
      ],
    );
  }

  IconData _getIconForField(String label) {
    switch (label.toLowerCase()) {
      case 'poste recherché':
        return Icons.work_outline;
      case 'description':
        return Icons.description_outlined;
      default:
        return Icons.edit_outlined;
    }
  }

  Widget _buildCVUpload(UserModel userModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CV',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text(_cvFileName ?? 'Ajouter un CV'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  elevation: 0,
                ),
                onPressed:
                    _isUploading ? null : () => _pickAndUploadCV(userModel),
              ),
            ),
            if (userModel.cvUrl.isNotEmpty) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.remove_red_eye, color: Colors.blue[700]),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: () => _viewCV(userModel.cvUrl),
              ),
            ],
          ],
        ),
        if (_isUploading)
          Column(
            children: [
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Téléchargement en cours... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickAndUploadCV(UserModel userModel) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      setState(() {
        _cvFileName = file.name;
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      try {
        String fileName = '${userModel.userId}_${path.basename(file.name)}';
        Reference ref = FirebaseStorage.instance.ref().child('cvs/$fileName');

        UploadTask uploadTask;
        if (file.bytes != null) {
          // Web
          uploadTask = ref.putData(file.bytes!);
        } else {
          // Mobile
          uploadTask = ref.putFile(File(file.path!));
        }

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // Modifier l'URL pour obtenir l'URL d'affichage

        await userModel.updateUserProfile({'cvUrl': downloadUrl});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV téléchargé avec succès')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement du CV: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _viewCV(String url) {
    return Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PDFViewerPage(
                  url: url,
                )));
  }

  Widget _buildDropdownField(String label, String? value,
      Function(String?) onChanged, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showSelectionBottomSheet(
              context, label, items, value, onChanged),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  _getIconForDropdown(label),
                  color: Colors.grey[600],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value ?? 'Sélectionnez $label',
                    style: TextStyle(
                      color: value == null ? Colors.grey[400] : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconForDropdown(String label) {
    switch (label.toLowerCase()) {
      case 'disponibilité':
        return Icons.calendar_today_outlined;
      case 'horaire':
        return Icons.access_time;
      case 'secteur d\'activité':
        return Icons.business_center_outlined;
      default:
        return Icons.list_alt_outlined;
    }
  }

  void _showSelectionBottomSheet(BuildContext context, String label,
      List<String> items, String? currentValue, Function(String?) onChanged) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sélectionnez $label',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item == currentValue;
                  return InkWell(
                    onTap: () {
                      onChanged(item);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue[50] : null,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 16,
                                color: isSelected
                                    ? Colors.blue[700]
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle, color: Colors.blue[700]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractTypes(UserModel userModel) {
    final contractTypes = [
      'CDD',
      'CDI',
      'Intérim',
      'Alternance',
      'Stage',
      'Indépendant'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de contrat recherché',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: contractTypes.map((type) {
            return FilterChip(
              label: Text(type),
              selected: userModel.contractTypes.contains(type),
              showCheckmark: false,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    userModel.contractTypes.add(type);
                  } else {
                    userModel.contractTypes.remove(type);
                  }
                });
              },
              selectedColor: Colors.blue[700],
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade200),
              labelStyle: TextStyle(
                color: userModel.contractTypes.contains(type)
                    ? Colors.white
                    : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExperiencesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Expériences professionnelles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: Colors.blue[700]),
                      onPressed: () => _showExperienceDialog(),
                    ),
                  ],
                ),
              ),
              if (_tempExperiences.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.work_outline,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune expérience ajoutée',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _showExperienceDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            foregroundColor: Colors.blue[700],
                            elevation: 0,
                          ),
                          child: const Text('Ajouter une expérience'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tempExperiences.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _tempExperiences.removeAt(oldIndex);
                      _tempExperiences.insert(newIndex, item);
                      for (var i = 0; i < _tempExperiences.length; i++) {
                        _tempExperiences[i].ordre = i;
                      }
                    });
                  },
                  proxyDecorator: (child, index, animation) => Material(
                    elevation: 0,
                    child: child,
                  ),
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final exp = _tempExperiences[index];
                    return Card(
                      key: ValueKey(exp.id),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.work_outline,
                            color: Colors.blue[700],
                          ),
                        ),
                        title: Text(
                          exp.poste,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              exp.entreprise,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateRange(
                                exp.dateDebut,
                                exp.dateFin,
                                exp.enCours,
                              ),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '(${_calculateDuration(
                                exp.dateDebut,
                                exp.dateFin,
                                exp.enCours,
                              )})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  exp.localisation,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildItemActions(
                              () => _showExperienceDialog(experience: exp),
                              () => _deleteExperience(exp),
                              null,
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemActions(
      Function() onEdit, Function() onDelete, Function()? onReorder) {
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: Icon(Icons.edit_outlined, color: Colors.blue[700]),
          onPressed: onEdit,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
        ),
        if (onReorder != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
            iconSize: 18,
            icon: Icon(Icons.drag_handle, color: Colors.grey[600]),
            onPressed: onReorder,
          ),
      ],
    );
  }

  String _formatDateRange(DateTime start, DateTime? end, bool isOngoing) {
    final dateFormat = DateFormat('MMM yyyy', 'fr_FR');
    final startStr = dateFormat.format(start);

    if (isOngoing) {
      return '$startStr - Aujourd\'hui';
    }

    if (end != null) {
      final endStr = dateFormat.format(end);
      return '$startStr - $endStr';
    }

    return startStr;
  }

  String _calculateDuration(DateTime start, DateTime? end, bool isOngoing) {
    final now = DateTime.now();
    final endDate = isOngoing ? now : (end ?? now);
    final difference = endDate.difference(start);

    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;

    if (years > 0 && months > 0) {
      return '$years an${years > 1 ? 's' : ''} $months mois';
    } else if (years > 0) {
      return '$years an${years > 1 ? 's' : ''}';
    } else if (months > 0) {
      return '$months mois';
    } else {
      return 'Moins d\'un mois';
    }
  }

  Future<void> _showExperienceDialog({Experience? experience}) async {
    final isEditing = experience != null;
    final formKey = GlobalKey<FormState>();
    final posteController = TextEditingController(text: experience?.poste);
    final entrepriseController =
        TextEditingController(text: experience?.entreprise);
    final descriptionController =
        TextEditingController(text: experience?.description);
    final localisationController =
        TextEditingController(text: experience?.localisation);
    DateTime? dateDebut = experience?.dateDebut ?? DateTime.now();
    DateTime? dateFin = experience?.dateFin;
    bool enCours = experience?.enCours ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing
                            ? 'Modifier l\'expérience'
                            : 'Ajouter une expérience',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDialogTextField(
                    controller: posteController,
                    label: 'Poste',
                    icon: Icons.work_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: entrepriseController,
                    label: 'Entreprise',
                    icon: Icons.business_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: localisationController,
                    label: 'Localisation',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(
                          label: 'Date de début',
                          selectedDate: dateDebut,
                          onChanged: (date) =>
                              setModalState(() => dateDebut = date),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (!enCours)
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Date de fin',
                            selectedDate: dateFin,
                            onChanged: (date) =>
                                setModalState(() => dateFin = date),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Poste actuel'),
                    value: enCours,
                    onChanged: (value) => setModalState(() {
                      enCours = value;
                      if (enCours) dateFin = null;
                    }),
                    activeColor: Colors.blue[700],
                    activeTrackColor: Colors.blue[100],
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey[200],
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: descriptionController,
                    label: 'Description',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (formKey.currentState?.validate() ?? false) {
                          final newExperience = Experience(
                            id: experience?.id ?? const Uuid().v4(),
                            poste: posteController.text,
                            entreprise: entrepriseController.text,
                            description: descriptionController.text,
                            dateDebut: dateDebut!,
                            dateFin: enCours ? null : dateFin,
                            enCours: enCours,
                            localisation: localisationController.text,
                            ordre: experience?.ordre ?? _tempExperiences.length,
                          );

                          if (isEditing) {
                            final index = _tempExperiences
                                .indexWhere((e) => e.id == experience.id);
                            setState(() {
                              _tempExperiences[index] = newExperience;
                            });
                          } else {
                            setState(() {
                              _tempExperiences.add(newExperience);
                            });
                          }
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        isEditing ? 'Modifier' : 'Ajouter',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
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
          borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) =>
          value?.isEmpty ?? true ? 'Ce champ est requis' : null,
    );
  }

  Widget _buildDatePicker({
    required String label,
    required DateTime? selectedDate,
    required Function(DateTime) onChanged,
    DateTime? minDate,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: minDate ?? DateTime(1900),
          lastDate: minDate != null ? DateTime(2100) : DateTime.now(),
          locale: const Locale('fr', 'FR'),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue[700]!,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selectedDate != null
                  ? DateFormat('d MMMM yyyy', 'fr_FR').format(selectedDate)
                  : 'Sélectionner',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExperience(Experience experience) async {
    setState(() {
      _tempExperiences.remove(experience);
    });
  }

  Widget _buildFormationsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Formation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: Colors.blue[700]),
                      onPressed: () => _showFormationDialog(),
                    ),
                  ],
                ),
              ),
              if (_tempFormations.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune formation ajoutée',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _showFormationDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            foregroundColor: Colors.blue[700],
                            elevation: 0,
                          ),
                          child: const Text('Ajouter une formation'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tempFormations.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _tempFormations.removeAt(oldIndex);
                      _tempFormations.insert(newIndex, item);
                      for (var i = 0; i < _tempFormations.length; i++) {
                        _tempFormations[i].ordre = i;
                      }
                    });
                  },
                  proxyDecorator: (child, index, animation) => Material(
                    elevation: 0,
                    child: child,
                  ),
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final formation = _tempFormations[index];
                    return Card(
                      key: ValueKey(formation.id),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.school_outlined,
                            color: Colors.purple[700],
                          ),
                        ),
                        title: Text(
                          formation.diplome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              formation.ecole,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateRange(
                                formation.dateDebut,
                                formation.dateFin,
                                formation.enCours,
                              ),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '(${_calculateDuration(
                                formation.dateDebut,
                                formation.dateFin,
                                formation.enCours,
                              )})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildItemActions(
                              () => _showFormationDialog(formation: formation),
                              () => _deleteFormation(formation),
                              null,
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showFormationDialog({Formation? formation}) async {
    final isEditing = formation != null;
    final formKey = GlobalKey<FormState>();
    final diplomeController = TextEditingController(text: formation?.diplome);
    final ecoleController = TextEditingController(text: formation?.ecole);
    final domaineController = TextEditingController(text: formation?.domaine);
    final descriptionController =
        TextEditingController(text: formation?.description);
    DateTime? dateDebut = formation?.dateDebut ?? DateTime.now();
    DateTime? dateFin = formation?.dateFin;
    bool enCours = formation?.enCours ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing
                              ? 'Modifier la formation'
                              : 'Ajouter une formation',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDialogTextField(
                      controller: diplomeController,
                      label: 'Diplôme',
                      icon: Icons.school_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: ecoleController,
                      label: 'École',
                      icon: Icons.school_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: domaineController,
                      label: 'Domaine',
                      icon: Icons.business_outlined,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            label: 'Date de début',
                            selectedDate: dateDebut,
                            onChanged: (date) =>
                                setModalState(() => dateDebut = date),
                            minDate: DateTime.now(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (!enCours)
                          Expanded(
                            child: _buildDatePicker(
                              label: 'Date de fin',
                              selectedDate: dateFin,
                              onChanged: (date) =>
                                  setModalState(() => dateFin = date),
                              minDate: DateTime.now(),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Étude en cours'),
                      value: enCours,
                      onChanged: (value) => setModalState(() {
                        enCours = value;
                        if (enCours) dateFin = null;
                      }),
                      activeColor: Colors.blue[700],
                      activeTrackColor: Colors.blue[100],
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[200],
                    ),
                    const SizedBox(height: 16),
                    _buildDialogTextField(
                      controller: descriptionController,
                      label: 'Description',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final newFormation = Formation(
                              id: formation?.id ?? const Uuid().v4(),
                              diplome: diplomeController.text,
                              ecole: ecoleController.text,
                              domaine: domaineController.text,
                              dateDebut: dateDebut!,
                              dateFin: enCours ? null : dateFin,
                              enCours: enCours,
                              description: descriptionController.text,
                              localisation: formation?.localisation ?? '',
                              ordre: formation?.ordre ?? _tempFormations.length,
                            );

                            if (isEditing) {
                              final index = _tempFormations
                                  .indexWhere((f) => f.id == formation.id);
                              setState(() {
                                _tempFormations[index] = newFormation;
                              });
                            } else {
                              setState(() {
                                _tempFormations.add(newFormation);
                              });
                            }
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          isEditing ? 'Modifier' : 'Ajouter',
                          style: const TextStyle(
                            fontSize: 16,
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
        ),
      ),
    );
  }

  Future<void> _deleteFormation(Formation formation) async {
    setState(() {
      _tempFormations.remove(formation);
    });
  }

  Widget _buildCompetencesList() {
    final niveaux = ['Débutant', 'Intermédiaire', 'Avancé', 'Expert'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Compétences',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: Colors.blue[700]),
                      onPressed: () => _showCompetenceDialog(),
                    ),
                  ],
                ),
              ),
              if (_tempCompetences.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.psychology_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune compétence ajoutée',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _showCompetenceDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            foregroundColor: Colors.blue[700],
                            elevation: 0,
                          ),
                          child: const Text('Ajouter une compétence'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tempCompetences.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _tempCompetences.removeAt(oldIndex);
                      _tempCompetences.insert(newIndex, item);
                      for (var i = 0; i < _tempCompetences.length; i++) {
                        _tempCompetences[i].ordre = i;
                      }
                    });
                  },
                  proxyDecorator: (child, index, animation) => Material(
                    elevation: 0,
                    child: child,
                  ),
                  buildDefaultDragHandles: false,
                  itemBuilder: (context, index) {
                    final competence = _tempCompetences[index];
                    return Card(
                      key: ValueKey(competence.id),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.psychology_outlined,
                            color: Colors.blue[700],
                          ),
                        ),
                        title: Text(
                          competence.nom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getNiveauColor(competence.niveau),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            competence.niveau,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildItemActions(
                              () =>
                                  _showCompetenceDialog(competence: competence),
                              () => _deleteCompetence(competence),
                              null,
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getNiveauColor(String niveau) {
    switch (niveau.toLowerCase()) {
      case 'débutant':
        return Colors.blue[400]!;
      case 'intermédiaire':
        return Colors.green[600]!;
      case 'avancé':
        return Colors.orange[700]!;
      case 'expert':
        return Colors.purple[700]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Future<void> _showCompetenceDialog({Competence? competence}) async {
    final isEditing = competence != null;
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController(text: competence?.nom);
    String selectedNiveau = competence?.niveau ?? 'Débutant';
    final niveaux = ['Débutant', 'Intermédiaire', 'Avancé', 'Expert'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing
                              ? 'Modifier la compétence'
                              : 'Ajouter une compétence',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDialogTextField(
                      controller: nomController,
                      label: 'Nom de la compétence',
                      icon: Icons.psychology_outlined,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Niveau',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: niveaux.map((niveau) {
                          final isSelected = selectedNiveau == niveau;
                          return InkWell(
                            onTap: () =>
                                setModalState(() => selectedNiveau = niveau),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: niveau != niveaux.last
                                        ? Colors.grey[200]!
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue[700]!
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                      color: isSelected
                                          ? Colors.blue[700]
                                          : Colors.transparent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          niveau,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? Colors.blue[700]
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          _getNiveauDescription(niveau),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (formKey.currentState?.validate() ?? false) {
                            final newCompetence = Competence(
                              id: competence?.id ?? const Uuid().v4(),
                              nom: nomController.text,
                              niveau: selectedNiveau,
                              ordre:
                                  competence?.ordre ?? _tempCompetences.length,
                            );

                            if (isEditing) {
                              final index = _tempCompetences
                                  .indexWhere((c) => c.id == competence.id);
                              setState(() {
                                _tempCompetences[index] = newCompetence;
                              });
                            } else {
                              setState(() {
                                _tempCompetences.add(newCompetence);
                              });
                            }
                            Navigator.pop(context);
                          }
                        },
                        child: Text(
                          isEditing ? 'Modifier' : 'Ajouter',
                          style: const TextStyle(
                            fontSize: 16,
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
        ),
      ),
    );
  }

  String _getNiveauDescription(String niveau) {
    switch (niveau.toLowerCase()) {
      case 'débutant':
        return 'Connaissances de base, apprentissage en cours';
      case 'intermédiaire':
        return 'Bonne maîtrise, autonomie sur les tâches courantes';
      case 'avancé':
        return 'Expertise confirmée, capable de former les autres';
      case 'expert':
        return 'Maîtrise exceptionnelle, référent dans le domaine';
      default:
        return '';
    }
  }

  Future<void> _deleteCompetence(Competence competence) async {
    setState(() {
      _tempCompetences.remove(competence);
    });
  }
}

// Ajout des modèles de données
class Experience {
  String id;
  String poste;
  String entreprise;
  String description;
  DateTime dateDebut;
  DateTime? dateFin;
  bool enCours;
  String localisation;
  int ordre;

  Experience({
    required this.id,
    required this.poste,
    required this.entreprise,
    required this.description,
    required this.dateDebut,
    this.dateFin,
    this.enCours = false,
    required this.localisation,
    required this.ordre,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'poste': poste,
        'entreprise': entreprise,
        'description': description,
        'dateDebut': dateDebut,
        'dateFin': dateFin,
        'enCours': enCours,
        'localisation': localisation,
        'ordre': ordre,
      };

  factory Experience.fromMap(Map<String, dynamic> map) => Experience(
        id: map['id'],
        poste: map['poste'],
        entreprise: map['entreprise'],
        description: map['description'],
        dateDebut: (map['dateDebut'] as Timestamp).toDate(),
        dateFin: map['dateFin'] != null
            ? (map['dateFin'] as Timestamp).toDate()
            : null,
        enCours: map['enCours'] ?? false,
        localisation: map['localisation'],
        ordre: map['ordre'],
      );
}

class Formation {
  String id;
  String diplome;
  String ecole;
  String domaine;
  DateTime dateDebut;
  DateTime? dateFin;
  bool enCours;
  String localisation;
  String? description;
  int ordre;

  Formation({
    required this.id,
    required this.diplome,
    required this.ecole,
    required this.domaine,
    required this.dateDebut,
    this.dateFin,
    this.enCours = false,
    required this.localisation,
    this.description,
    required this.ordre,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'diplome': diplome,
        'ecole': ecole,
        'domaine': domaine,
        'dateDebut': dateDebut,
        'dateFin': dateFin,
        'enCours': enCours,
        'localisation': localisation,
        'description': description,
        'ordre': ordre,
      };

  factory Formation.fromMap(Map<String, dynamic> map) => Formation(
        id: map['id'],
        diplome: map['diplome'],
        ecole: map['ecole'],
        domaine: map['domaine'],
        dateDebut: (map['dateDebut'] as Timestamp).toDate(),
        dateFin: map['dateFin'] != null
            ? (map['dateFin'] as Timestamp).toDate()
            : null,
        enCours: map['enCours'] ?? false,
        localisation: map['localisation'],
        description: map['description'],
        ordre: map['ordre'],
      );
}

class Competence {
  String id;
  String nom;
  String niveau; // Débutant, Intermédiaire, Avancé, Expert
  int ordre;

  Competence({
    required this.id,
    required this.nom,
    required this.niveau,
    required this.ordre,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'niveau': niveau,
        'ordre': ordre,
      };

  factory Competence.fromMap(Map<String, dynamic> map) => Competence(
        id: map['id'],
        nom: map['nom'],
        niveau: map['niveau'],
        ordre: map['ordre'],
      );
}
