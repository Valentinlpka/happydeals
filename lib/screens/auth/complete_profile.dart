import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:provider/provider.dart';

class ProfileCompletionPage extends StatefulWidget {
  const ProfileCompletionPage({super.key});

  @override
  _ProfileCompletionPageState createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModel>(context, listen: false);
    void completeProfile() async {
      // Mettre à jour le profil utilisateur

      await userModel.updateUserProfile({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'isProfileComplete': true,
      });

      // Créer un client Stripe
      Map<String, dynamic>? userData = await userModel.getCurrentUser();
      final FirebaseFunctions functions = FirebaseFunctions.instance;

      Future<String> createCustomer() async {
        try {
          final result =
              await functions.httpsCallable('createStripeCustomer').call();

          if (result.data['customerId'] != null) {
            await userModel.updateUserProfile(
                {'stripeCustomerId': result.data['customerId']});
          }

          return result.data['customerId'];
        } catch (e) {
          print('Erreur lors de la création du client Stripe: $e');
          rethrow;
        }
      }

      Navigator.pushReplacementNamed(context, '/home');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Compléter votre profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Adresse'),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: completeProfile,
              child: const Text('Terminer'),
            ),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              child: const Text('Plus tard'),
            ),
          ],
        ),
      ),
    );
  }
}
