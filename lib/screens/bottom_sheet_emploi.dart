import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class ApplicationBottomSheet extends StatefulWidget {
  final String jobOfferId;
  final String companyId;

  const ApplicationBottomSheet({
    super.key,
    required this.jobOfferId,
    required this.companyId,
  });

  @override
  _ApplicationBottomSheetState createState() => _ApplicationBottomSheetState();
}

class _ApplicationBottomSheetState extends State<ApplicationBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _cvUrl;
  String? _cvFileName;
  File? _coverLetterFile;
  bool _isLoading = false;
  bool _hasApplied = false;

  final int _maxFileSizeInBytes = 3 * 1024 * 1024; // 3 Mo

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkExistingApplication();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userData.exists) {
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _cvUrl = userData['cvUrl'];
          _cvFileName = userData['cvFileName'];
        });
      }
    }
  }

  Future<void> _checkExistingApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final existingApplication = await FirebaseFirestore.instance
          .collection('applications')
          .where('applicantId', isEqualTo: user.uid)
          .where('jobOfferId', isEqualTo: widget.jobOfferId)
          .get();

      setState(() {
        _hasApplied = existingApplication.docs.isNotEmpty;
      });

      if (_hasApplied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez déjà postulé à cette offre.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      if (await file.length() > _maxFileSizeInBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le fichier dépasse la limite de 3 Mo')),
        );
        return;
      }

      if (type == 'cv') {
        String? url = await _uploadFile(file, 'cvs');
        if (url != null) {
          setState(() {
            _cvUrl = url;
            _cvFileName = result.files.single.name;
          });
          // Sauvegarder le CV dans le profil utilisateur
          await _saveUserCV(url, result.files.single.name);
        }
      } else {
        setState(() {
          _coverLetterFile = file;
        });
      }
    }
  }

  Future<void> _saveUserCV(String cvUrl, String fileName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'cvUrl': cvUrl,
        'cvFileName': fileName,
      });
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      final fileName = path.basename(file.path);
      final destination =
          'applications/$folder/${FirebaseAuth.instance.currentUser!.uid}/$fileName';

      final ref = FirebaseStorage.instance.ref(destination);
      final uploadTask = ref.putFile(file);

      final snapshot = await uploadTask.whenComplete(() {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> _submitApplication() async {
    if (_hasApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez déjà postulé à cette offre.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? coverLetterUrl;

        if (_coverLetterFile != null) {
          coverLetterUrl =
              await _uploadFile(_coverLetterFile!, 'cover_letters');
        }

        DocumentSnapshot jobSnapshot = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.jobOfferId)
            .get();
        Map<String, dynamic> jobData =
            jobSnapshot.data() as Map<String, dynamic>;

        DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
            .collection('companys')
            .doc(jobData['companyId'])
            .get();
        Map<String, dynamic> companyData =
            companySnapshot.data() as Map<String, dynamic>;

        // Utiliser une transaction pour créer la candidature et la notification
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Créer une référence pour la nouvelle candidature
          DocumentReference applicationRef =
              FirebaseFirestore.instance.collection('applications').doc();

          // Créer la candidature
          transaction.set(applicationRef, {
            'jobOfferId': widget.jobOfferId,
            'companyId': widget.companyId,
            'jobTitle': jobData['job_title'],
            'companyName': companyData['name'],
            'companyLogo': companyData['logo'],
            'applicantId': FirebaseAuth.instance.currentUser!.uid,
            'name': _nameController.text,
            'email': _emailController.text,
            'phone': _phoneController.text,
            'cvUrl': _cvUrl,
            'cvFileName': _cvFileName,
            'coverLetterUrl': coverLetterUrl,
            'status': 'pending',
            'appliedAt': FieldValue.serverTimestamp(),
          });

          // Créer une notification pour l'entreprise
          DocumentReference notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();
          transaction.set(notificationRef, {
            'userId': widget
                .companyId, // L'ID de l'entreprise qui recevra la notification
            'type': 'new_application',
            'message':
                'Nouvelle candidature pour le poste ${jobData['job_title']} de ${_nameController.text}',
            'relatedId': applicationRef.id, // L'ID de la candidature
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        });

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidature envoyée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi de la candidature'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Postuler maintenant',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 20),
            if (_hasApplied)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Vous avez déjà postulé à cette offre.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(_nameController, 'Nom complet', Icons.person),
                  const SizedBox(height: 15),
                  _buildTextField(_emailController, 'Email', Icons.email),
                  const SizedBox(height: 15),
                  _buildTextField(_phoneController, 'Téléphone', Icons.phone),
                  const SizedBox(height: 20),
                  _buildCVButton(),
                  const SizedBox(height: 10),
                  _buildFileUploadButton('Lettre de motivation',
                      _coverLetterFile, () => _pickFile('coverLetter')),
                  const SizedBox(height: 10),
                  const Text(
                    'Limite de taille par fichier : 3 Mo',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        _hasApplied || _isLoading ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _hasApplied ? Colors.grey : Colors.blue[800],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_hasApplied
                            ? 'Déjà postulé'
                            : 'Envoyer ma candidature'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue[800]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue[800]!, width: 2),
        ),
      ),
      validator: (value) => value!.isEmpty ? 'Ce champ est requis' : null,
    );
  }

  Widget _buildCVButton() {
    return ElevatedButton.icon(
      onPressed: () => _pickFile('cv'),
      icon: Icon(_cvUrl != null ? Icons.check : Icons.upload_file),
      label: Text(_cvFileName != null ? 'CV: $_cvFileName' : 'Ajouter un CV'),
      style: ElevatedButton.styleFrom(
        foregroundColor: _cvUrl != null ? Colors.white : Colors.black,
        backgroundColor: _cvUrl != null ? Colors.green : Colors.grey[300],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildFileUploadButton(
      String label, File? file, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(file != null ? Icons.check : Icons.upload_file),
      label: Text(file != null ? '$label sélectionné' : 'Ajouter $label'),
      style: ElevatedButton.styleFrom(
        foregroundColor: file != null ? Colors.white : Colors.black,
        backgroundColor: file != null ? Colors.green : Colors.grey[300],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
