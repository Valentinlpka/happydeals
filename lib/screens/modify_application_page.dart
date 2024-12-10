import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class EditApplicationPage extends StatefulWidget {
  final DocumentSnapshot application;

  const EditApplicationPage({super.key, required this.application});

  @override
  _EditApplicationPageState createState() => _EditApplicationPageState();
}

class _EditApplicationPageState extends State<EditApplicationPage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  String? _cvUrl;
  String? _coverLetterUrl;
  bool _isLoading = false;
  final int _maxFileSizeInBytes = 3 * 1024 * 1024; // 3 Mo

  @override
  void initState() {
    super.initState();
    var data = widget.application.data() as Map<String, dynamic>;
    _nameController = TextEditingController(text: data['name']);
    _emailController = TextEditingController(text: data['email']);
    _phoneController = TextEditingController(text: data['phone']);
    _cvUrl = data['cvUrl'];
    _coverLetterUrl = data['coverLetterUrl'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile(String type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      if (await file.length() > _maxFileSizeInBytes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Le fichier dépasse la limite de 3 Mo'),
              backgroundColor: Colors.red),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        String? oldUrl = type == 'cv' ? _cvUrl : _coverLetterUrl;
        if (oldUrl != null) {
          await _deleteOldFile(oldUrl);
        }

        String path =
            'applications/${widget.application.id}/$type/${result.files.single.name}';
        Reference ref = FirebaseStorage.instance.ref().child(path);
        await ref.putFile(file);
        String downloadUrl = await ref.getDownloadURL();

        setState(() {
          if (type == 'cv') {
            _cvUrl = downloadUrl;
          } else {
            _coverLetterUrl = downloadUrl;
          }
        });

        await widget.application.reference.update({
          '${type}Url': downloadUrl,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$type uploadé avec succès'),
              backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur lors de l\'upload: $e'),
              backgroundColor: Colors.red),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteOldFile(String fileUrl) async {
    try {
      await FirebaseStorage.instance.refFromURL(fileUrl).delete();
    } catch (e) {
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.application.reference.update({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Modifications enregistrées avec succès'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _launchURL(String? url) async {
    if (url != null && await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible d\'ouvrir le document'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var data = widget.application.data() as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier la candidature'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveChanges,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(data),
                  const SizedBox(height: 20),
                  _buildTextField(_nameController, 'Nom complet', Icons.person),
                  const SizedBox(height: 15),
                  _buildTextField(_emailController, 'Email', Icons.email),
                  const SizedBox(height: 15),
                  _buildTextField(_phoneController, 'Téléphone', Icons.phone),
                  const SizedBox(height: 20),
                  Text('Documents',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800])),
                  const SizedBox(height: 10),
                  _buildDocumentSection(
                      'CV', _cvUrl, () => _pickAndUploadFile('cv')),
                  const SizedBox(height: 15),
                  _buildDocumentSection('Lettre de motivation', _coverLetterUrl,
                      () => _pickAndUploadFile('coverLetter')),
                  const SizedBox(height: 10),
                  const Text(
                    'Limite de taille de fichier: 3 Mo. Format accepté : PDF',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> data) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (data['jobTitle']),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800]),
            ),
            const SizedBox(height: 8),
            Text(
              (data['companyName']),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Postuler le: ${DateFormat('dd/MM/yyyy à HH:mm').format(data['appliedAt'].toDate())}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
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
    );
  }

  Widget _buildDocumentSection(
      String title, String? url, VoidCallback onUpload) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (url != null)
          ElevatedButton(
            onPressed: () => _launchURL(url),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Voir'),
          ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onUpload,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
          child: Text(url != null ? 'Remplacer' : 'Ajouter'),
        ),
      ],
    );
  }
}
