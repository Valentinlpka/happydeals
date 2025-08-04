import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/screens/auth/onboarding_questionnaire_page.dart';
import 'package:happy/screens/main_container.dart';

class PhoneAuthPage extends StatefulWidget {
  final bool isLogin; // Nouveau paramètre pour différencier connexion/inscription
  
  const PhoneAuthPage({super.key, this.isLogin = false});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  int? _resendToken;
  int _countdown = 60;
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
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _countdown > 0) {
        setState(() => _countdown--);
        _startCountdown();
      }
    });
  }

  Future<void> _sendVerificationCode() async {
    if (_phoneController.text.trim().isEmpty) {
      _showErrorSnackBar('Veuillez entrer votre numéro de téléphone');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+33${_phoneController.text.trim()}',
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          if (mounted) {
            _navigateAfterSuccess();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showErrorSnackBar(
              e.message ?? 'Erreur lors de la vérification du numéro'
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _codeSent = true;
              _verificationId = verificationId;
              _resendToken = resendToken;
            });
            _startCountdown();
            _showSuccessSnackBar('Code envoyé par SMS');
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Erreur lors de l\'envoi du code');
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().isEmpty) {
      _showErrorSnackBar('Veuillez entrer le code de vérification');
      return;
    }

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (mounted) {
        _navigateAfterSuccess(userCredential);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Code incorrect. Veuillez réessayer.');
      }
    }
  }

  void _navigateAfterSuccess([UserCredential? userCredential]) {
    if (widget.isLogin) {
      // Mode connexion : aller à MainContainer
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const MainContainer(),
        ),
        (route) => false, // Supprime toute la pile de navigation
      );
    } else {
      // Mode inscription : aller au questionnaire d'onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const OnboardingQuestionnairePage(),
        ),
      );
    }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Header
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _codeSent ? Icons.sms_outlined : Icons.phone_android_rounded,
                            size: 48,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _codeSent ? 'Vérification SMS' : 'Numéro de téléphone',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _codeSent 
                              ? 'Entrez le code reçu par SMS au\n+33 ${_phoneController.text}'
                              : widget.isLogin 
                                  ? 'Nous vous enverrons un code de vérification'
                                  : 'Nous vous enverrons un code de vérification',
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
                  
                  if (!_codeSent) ...[
                    // Formulaire numéro de téléphone
                    _buildPhoneForm(),
                  ] else ...[
                    // Formulaire code de vérification
                    _buildCodeForm(),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      children: [
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
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/france_flag.png',
                      width: 24,
                      height: 16,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 24,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Center(
                            child: Text(
                              'FR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '+33',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              hintText: "6 12 34 56 78",
              hintStyle: TextStyle(color: Colors.grey[500]),
            ),
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
            onPressed: _isLoading ? null : _sendVerificationCode,
            child: _isLoading
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : Text(
                    widget.isLogin ? 'Se connecter' : 'Envoyer le code',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeForm() {
    return Column(
      children: [
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
            controller: _codeController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              hintText: "123456",
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 24,
                letterSpacing: 8,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Timer et renvoyer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_countdown > 0) ...[
              Text(
                'Renvoyer dans ${_countdown}s',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ] else ...[
              TextButton(
                onPressed: _sendVerificationCode,
                child: const Text('Renvoyer le code'),
              ),
            ],
          ],
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
            onPressed: _isLoading ? null : _verifyCode,
            child: _isLoading
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : Text(
                    widget.isLogin ? 'Se connecter' : 'Vérifier le code',
                    style: const TextStyle(
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