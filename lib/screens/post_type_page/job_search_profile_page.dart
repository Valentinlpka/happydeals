import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/pdf_viewer_page.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil de recherche d\'emploi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<UserModel>(
        builder: (context, userModel, child) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSwitchTile('Partager l\'email', userModel.showEmail,
                        (value) => userModel.showEmail = value),
                    _buildSwitchTile(
                        'Partager le téléphone',
                        userModel.showPhone,
                        (value) => userModel.showPhone = value),
                    const SizedBox(height: 16),
                    _buildTextField(
                        'Poste recherché',
                        userModel.desiredPosition,
                        (value) => userModel.desiredPosition = value),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      'Secteur d\'activité',
                      userModel.industrySector,
                      (value) => userModel.industrySector = value!,
                      _industrySectors,
                    ),
                    const SizedBox(height: 16),
                    _buildCVUpload(userModel),
                    const SizedBox(height: 16),
                    _buildTextField('Description', userModel.description,
                        (value) => userModel.description = value,
                        maxLines: 3),
                    const SizedBox(height: 16),
                    _buildDropdownField('Disponibilité', userModel.availability,
                        (value) => userModel.availability = value!, [
                      'Tout de suite',
                      'Dans 1 mois',
                      'Dans 3 mois',
                      'À définir'
                    ]),
                    const SizedBox(height: 16),
                    _buildContractTypes(userModel),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                        'Horaire',
                        userModel.workingHours,
                        (value) => userModel.workingHours = value!,
                        ['Mi-temps', 'Temps plein', 'Temps partiel']),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            userModel.updateUserProfile({
                              'showEmail': userModel.showEmail,
                              'showPhone': userModel.showPhone,
                              'desiredPosition': userModel.desiredPosition,
                              'description': userModel.description,
                              'availability': userModel.availability,
                              'contractTypes': userModel.contractTypes,
                              'workingHours': userModel.workingHours,
                              'industrySector': userModel.industrySector,
                              'timestampProfile': Timestamp.now()
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Profil de recherche d\'emploi mis à jour avec succès')),
                            );
                          }
                        },
                        child: const Text('Enregistrer',
                            style: TextStyle(fontSize: 18)),
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

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildTextField(
      String label, String initialValue, Function(String) onSaved,
      {int maxLines = 1}) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Ce champ ne peut pas être vide';
        }
        return null;
      },
      onSaved: (value) => onSaved(value!),
    );
  }

  Widget _buildCVUpload(UserModel userModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CV',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: Text(_cvFileName ?? 'Ajouter un CV'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.grey[200],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    _isUploading ? null : () => _pickAndUploadCV(userModel),
              ),
            ),
            if (userModel.cvUrl.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.remove_red_eye),
                onPressed: () => _viewCV(userModel.cvUrl),
              ),
          ],
        ),
        if (_isUploading)
          Column(
            children: [
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 4),
              Text(
                  'Téléchargement en cours... ${(_uploadProgress * 100).toStringAsFixed(0)}%'),
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
    // Assurez-vous que la valeur actuelle est dans la liste des éléments
    if (value != null && !items.contains(value)) {
      value = null; // Réinitialisez la valeur si elle n'est pas dans la liste
    }

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      // Ajoutez un hint pour gérer le cas où la valeur est null
      hint: Text('Sélectionnez $label'),
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
        const Text('Type de contrat recherché',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: contractTypes.map((type) {
            return FilterChip(
              label: Text(type),
              selected: userModel.contractTypes.contains(type),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    userModel.contractTypes.add(type);
                  } else {
                    userModel.contractTypes.remove(type);
                  }
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              checkmarkColor: Theme.of(context).primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }
}
