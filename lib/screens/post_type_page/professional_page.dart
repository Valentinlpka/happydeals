import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/post_type_page/job_search_profile_page.dart';
import 'package:provider/provider.dart';

class GeneralProfilePage extends StatefulWidget {
  const GeneralProfilePage({super.key});

  @override
  _GeneralProfilePageState createState() => _GeneralProfilePageState();
}

class _GeneralProfilePageState extends State<GeneralProfilePage> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil général'),
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
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: NetworkImage(userModel.profileUrl),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              radius: 20,
                              child: IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.white),
                                onPressed: () {
                                  // Implement image picker
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField('Prénom', userModel.firstName,
                        (value) => userModel.firstName = value),
                    _buildTextField('Nom', userModel.lastName,
                        (value) => userModel.lastName = value),
                    _buildTextField('Email', userModel.email,
                        (value) => userModel.email = value),
                    _buildTextField('Téléphone', userModel.phone,
                        (value) => userModel.phone = value),
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
                              'firstName': userModel.firstName,
                              'lastName': userModel.lastName,
                              'email': userModel.email,
                              'phone': userModel.phone,
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Profil mis à jour avec succès')),
                            );
                          }
                        },
                        child: const Text('Enregistrer',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const JobSearchProfilePage()),
                          );
                        },
                        child: const Text(
                            'Configurer mon profil de recherche d\'emploi',
                            style: TextStyle(fontSize: 16)),
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

  Widget _buildTextField(
      String label, String initialValue, Function(String) onSaved) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        initialValue: initialValue,
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
      ),
    );
  }
}
