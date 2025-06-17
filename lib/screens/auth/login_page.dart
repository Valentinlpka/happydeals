import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/auth/register_page.dart';
import 'package:happy/screens/complete_profile_page.dart';
import 'package:happy/screens/main_container.dart';
import 'package:happy/screens/nearby_entities_page.dart';
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
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      // Initialiser ScreenUtil avec les dimensions de l'écran
      ScreenUtil.init(
        context,
        designSize: const Size(375, 812), // iPhone X dimensions
      );
      _isInitialized = true;
    }
  }

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
          if (!mounted) return;
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
      if (!mounted) return;
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
                    builder: (context) => const CompleteProfilePage(),
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            SizedBox(height: 20.h),
                            Hero(
                              tag: 'logo',
                              child: Image.asset(
                                'assets/mon_logo.png',
                                height: 80.h,
                              ),
                            ),
                            SizedBox(height: 20.h),
                            Text(
                              'Bienvenue !',
                              style: TextStyle(
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E3799),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Connectez-vous pour découvrir les meilleures offres',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            _buildInputField(
                              controller: _emailController,
                              hint: "E-mail",
                              icon: Icons.email_outlined,
                            ),
                            SizedBox(height: 12.h),
                            _buildInputField(
                              controller: _passwordController,
                              hint: "Mot de passe",
                              icon: Icons.lock_outline,
                              isPassword: true,
                              isPasswordVisible: _passwordVisible,
                              onPasswordVisibilityChanged: () {
                                setState(
                                    () => _passwordVisible = !_passwordVisible);
                              },
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Logique mot de passe oublié
                                },
                                child: Text(
                                  'Mot de passe oublié ?',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 16.h),
                            _buildLoginButton(),
                            SizedBox(height: 16.h),
                            _buildGoogleButton(),
                            SizedBox(height: 16.h),
                            _buildDivider(),
                            SizedBox(height: 16.h),
                            _buildSignUpLink(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onPasswordVisibilityChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isPasswordVisible,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 14.sp),
          prefixIcon: Icon(icon, color: Colors.blue[700], size: 20.w),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                    size: 20.w,
                  ),
                  onPressed: onPasswordVisibilityChanged,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                height: 20.h,
                width: 20.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Connexion',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        icon: Image.asset('assets/images/google_logo.png', height: 20.h),
        label: Text(
          'Continuer avec Google',
          style: TextStyle(fontSize: 14.sp, color: Colors.black87),
        ),
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          side: BorderSide(color: Colors.grey[300]!),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text('OU',
              style: TextStyle(color: Colors.grey[600], fontSize: 12.sp)),
        ),
        Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
      ],
    );
  }

  Widget _buildSignUpLink() {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignUpPage()),
        ),
        child: RichText(
          text: TextSpan(
            text: "Vous n'avez pas encore de compte ? ",
            style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
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
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final result = await _auth.signInWithGoogle();
      if (result == 'new_user') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CompleteProfilePage(),
          ),
        );
      } else if (result == 'success') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const NearbyEntitiesPage(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la connexion: $e')),
      );
    }
  }
}
