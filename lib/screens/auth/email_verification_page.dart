import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/auth/onboarding_questionnaire_page.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  
  bool _isCheckingVerification = false;
  bool _canResendEmail = true;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  Timer? _autoCheckTimer;

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

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    
    // Vérifier automatiquement toutes les 3 secondes
    _startAutoCheck();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _resendTimer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _startAutoCheck() {
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isCheckingVerification) {
        _checkEmailVerification(autoCheck: true);
      }
    });
  }

  Future<void> _checkEmailVerification({bool autoCheck = false}) async {
    if (!autoCheck) {
      setState(() => _isCheckingVerification = true);
    }

    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified && mounted) {
        // Email vérifié, rediriger vers l'onboarding
        _autoCheckTimer?.cancel();
        
        if (!autoCheck) {
          _showSuccessSnackBar('Email vérifié avec succès !');
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const OnboardingQuestionnairePage(),
            ),
            (route) => false,
          );
        }
      } else if (!autoCheck) {
        _showErrorSnackBar('Email non vérifié. Vérifiez votre boîte mail.');
      }
    } catch (e) {
      if (!autoCheck) {
        _showErrorSnackBar('Erreur lors de la vérification: $e');
      }
    } finally {
      if (!autoCheck && mounted) {
        setState(() => _isCheckingVerification = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResendEmail) return;

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      _showSuccessSnackBar('Email de vérification renvoyé !');
      
      // Démarrer le countdown de 60 secondes
      setState(() {
        _canResendEmail = false;
        _resendCountdown = 60;
      });
      
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _resendCountdown--;
          if (_resendCountdown <= 0) {
            _canResendEmail = true;
            timer.cancel();
          }
        });
      });
    } catch (e) {
      _showErrorSnackBar('Erreur lors du renvoi: $e');
    }
  }

  Future<void> _openMailApp(String appUrl, String fallbackUrl) async {
    final Uri url = Uri.parse(appUrl);
    final Uri fallback = Uri.parse(fallbackUrl);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Impossible d\'ouvrir l\'application de mail');
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de l\'ouverture: $e');
    }
  }

  void _showErrorSnackBar(String message) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildEmailCard(userEmail),
                      const SizedBox(height: 32),
                      _buildMailAppsSection(),
                      const SizedBox(height: 32),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_unread_outlined,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Vérifiez votre email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Nous avons envoyé un lien de vérification\nà votre adresse email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailCard(String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.email_outlined,
              color: Colors.blue[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Email envoyé à :',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMailAppsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.open_in_new, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Ouvrir votre boîte mail',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMailAppButton(
                  'Gmail',
                  Icons.email,
                  Colors.red,
                  () => _openMailApp('googlegmail://', 'https://mail.google.com'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMailAppButton(
                  'Outlook',
                  Icons.email,
                  Colors.blue,
                  () => _openMailApp('ms-outlook://', 'https://outlook.live.com'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMailAppButton(
                  'Mail',
                  Icons.mail,
                  Colors.grey,
                  () => _openMailApp('message://', 'mailto:'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMailAppButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isCheckingVerification ? null : _checkEmailVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isCheckingVerification
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Text(
                    'J\'ai vérifié mon email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _canResendEmail ? _resendVerificationEmail : null,
          child: Text(
            _canResendEmail
                ? 'Renvoyer l\'email de vérification'
                : 'Renvoyer dans ${_resendCountdown}s',
            style: TextStyle(
              color: _canResendEmail ? Colors.blue[700] : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Vérifiez aussi vos spams si vous ne trouvez pas l\'email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {
            FirebaseAuth.instance.signOut();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Retour à la connexion'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
