import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/auth/email_verification_page.dart';
import 'package:happy/screens/auth/login_page.dart';
import 'package:happy/screens/auth/onboarding_questionnaire_page.dart';
import 'package:happy/screens/auth/phone_auth_page.dart';
import 'package:happy/services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  final Function()? onTap;

  const SignUpPage({super.key, this.onTap});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with TickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _passwordVisible = false;
  bool _isLoading = false;
  bool _isPhoneAuth = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorSnackBar('Veuillez remplir tous les champs');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (credential.user != null && mounted) {
        // Envoyer l'email de vérification
        await credential.user!.sendEmailVerification();
        
        // Rediriger vers la page de vérification email
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const EmailVerificationPage(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Erreur lors de l\'inscription';
        switch (e.code) {
          case 'weak-password':
            message = 'Le mot de passe est trop faible';
            break;
          case 'email-already-in-use':
            message = 'Cette adresse email est déjà utilisée';
            break;
          case 'invalid-email':
            message = 'Adresse email invalide';
            break;
        }
        _showErrorSnackBar(message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erreur lors de l\'inscription: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _signUpWithPhone() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhoneAuthPage(isLogin: false),
      ),
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    size: 48,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Vérifiez votre email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Un email de vérification a été envoyé à votre adresse. Cliquez sur le lien pour continuer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () async {
                    await _auth.currentUser?.sendEmailVerification();
                    if (mounted) {
                      _showSuccessSnackBar('Email de vérification renvoyé');
                    }
                  },
                  child: const Text('Renvoyer l\'email'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _auth.currentUser?.reload();
                      if (_auth.currentUser?.emailVerified == true) {
                        if (mounted) {
                          Navigator.of(context).pop();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingQuestionnairePage(),
                            ),
                            (route) => false, // Supprime toute la pile de navigation
                          );
                        }
                      } else {
                        _showErrorSnackBar('Veuillez d\'abord vérifier votre email');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'J\'ai vérifié mon email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo et titre
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Image(
                          image: AssetImage('assets/mon_logo.png'),
                          height: 60,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Rejoignez Up !',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Découvrez et soutenez les commerces locaux',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Sélecteur de méthode d'inscription
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPhoneAuth = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isPhoneAuth ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: !_isPhoneAuth ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 20,
                                    color: !_isPhoneAuth ? Colors.blue[700] : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Email',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: !_isPhoneAuth ? Colors.blue[700] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPhoneAuth = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isPhoneAuth ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _isPhoneAuth ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 20,
                                    color: _isPhoneAuth ? Colors.blue[700] : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Téléphone',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _isPhoneAuth ? Colors.blue[700] : Colors.grey[600],
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
                  
                  const SizedBox(height: 24),
                  
                  // Formulaire
                  if (!_isPhoneAuth) ...[
                    // Inscription par email
                    _buildEmailForm(),
                  ] else ...[
                    // Inscription par téléphone
                    _buildPhoneForm(),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Lien vers connexion
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Vous avez déjà un compte ? ",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Login(),
                            ),
                          );
                        },
                        child: Text(
                          "Se connecter",
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        // Champ email
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
              hintText: "Votre adresse email",
              hintStyle: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Champ mot de passe
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.lock_outlined, color: Colors.grey[600]),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
              hintText: "Votre mot de passe",
              hintStyle: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Bouton d'inscription
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _signUpWithEmail,
            child: _isLoading
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Text(
                    'S\'inscrire avec email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.phone_android_rounded,
                size: 64,
                color: Colors.blue[700],
              ),
              const SizedBox(height: 16),
              const Text(
                'Inscription par téléphone',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous recevrez un code de vérification par SMS',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _signUpWithPhone,
            child: const Text(
              'Continuer avec le téléphone',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
