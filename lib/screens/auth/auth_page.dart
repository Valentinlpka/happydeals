import 'package:flutter/material.dart';
import 'package:happy/screens/auth/login_page.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    // AuthPage doit juste afficher la page de connexion
    // AuthWrapper s'occupe déjà de toute la logique d'authentification
    debugPrint('🔍 AuthPage: Affichage de Login');
    return const Login();
  }
}