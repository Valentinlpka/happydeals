import 'package:flutter/material.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/auth/complete_profile.dart';
import 'package:happy/screens/auth/register_page.dart';
import 'package:happy/screens/main_container.dart';
import 'package:happy/services/analytics_service.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class Login extends StatefulWidget {
  final Function()? onTap;
  const Login({super.key, this.onTap});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final AnalyticsService _analytics = AnalyticsService();
  bool _passwordVisible = false;
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      final conversationService =
          Provider.of<ConversationService>(context, listen: false);

      String? result = await _auth.signIn(
        context: context,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result == 'Success') {
        await _analytics.logEvent(
          name: 'login',
          parameters: {
            'success': true,
            'method': 'email',
            'user_id': userModel.userId,
          },
        );

        // Initialiser le service de conversation après une connexion réussie
        await conversationService.initializeForUser(userModel.userId);

        bool isComplete = await userModel.isProfileComplete();
        if (isComplete) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MainContainer(),
            ),
          );
        } else {
          _showProfileCompletionDialog();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result ?? 'Une erreur est survenue')),
        );
      }
    } catch (e) {
      await _analytics.logEvent(
        name: 'login_error',
        parameters: {
          'method': 'email',
          'error': e.toString(),
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showProfileCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Compléter votre profil'),
          content:
              const Text('Voulez-vous compléter votre profil maintenant ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Plus tard'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MainContainer(),
                  ),
                );
              },
            ),
            TextButton(
              child: const Text('Compléter'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileCompletionPage(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                // Logo et titre
                Center(
                  child: Hero(
                    tag: 'logo',
                    child: Image.asset(
                      'assets/mon_logo.png',
                      height: 120,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Textes d'introduction
                const Text(
                  'Bienvenue !',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3799),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Connectez-vous pour découvrir les meilleures offres',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                // Champs de saisie
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: "E-mail",
                      prefixIcon:
                          Icon(Icons.email_outlined, color: Colors.blue[700]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      hintText: "Mot de passe",
                      prefixIcon:
                          Icon(Icons.lock_outline, color: Colors.blue[700]),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Logique mot de passe oublié
                    },
                    child: Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Bouton de connexion
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Connexion',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                // Bouton de connexion avec Google
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                      });
                      try {
                        String? result = await _auth.signInWithGoogle(context);
                        if (!mounted) return;

                        if (result == 'Success') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MainContainer(),
                            ),
                          );
                        } else if (result == 'NewUser') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProfileCompletionPage(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content:
                                    Text(result ?? 'Une erreur est survenue')),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    },
                    icon: Image.asset(
                      'assets/images/google_logo.png',
                      height: 24,
                    ),
                    label: const Text(
                      'Continuer avec Google',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Séparateur
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child:
                          Text('OU', style: TextStyle(color: Colors.grey[600])),
                    ),
                    Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),
                const SizedBox(height: 30),
                // Lien d'inscription
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SignUpPage()),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: "Vous n'avez pas encore de compte ? ",
                        style: TextStyle(color: Colors.grey[600]),
                        children: [
                          TextSpan(
                            text: "Je m'inscris",
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
