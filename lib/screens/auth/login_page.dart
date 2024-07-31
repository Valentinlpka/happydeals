import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';

class Login extends StatefulWidget {
  final Function()? onTap;
  const Login({
    super.key,
    this.onTap,
  });

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _passwordVisible = false;
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _signIn() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    String? result = await _auth.signIn(
      context: context,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (result == 'Success') {
      bool isComplete = await userModel.isProfileComplete();
      if (isComplete) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showProfileCompletionDialog();
      }
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result!)));
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
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
            TextButton(
              child: const Text('Compléter'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/profile_completion');
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
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 15.0, right: 15),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50.0),
                  child: Image(
                    image: AssetImage('assets/mon_logo.png'),
                    height: 60,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 70,
                      child: Text(
                        'Connexion',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 70,
                      child: TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                            contentPadding: const EdgeInsets.all(5),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            prefixIcon: const Icon(Icons.alternate_email),
                            hintText: "E-mail"),
                      ),
                    ),
                    SizedBox(
                      height: 50,
                      child: TextField(
                        controller: _passwordController,
                        obscureText: !_passwordVisible,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                            contentPadding: const EdgeInsets.all(5),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _passwordVisible = !_passwordVisible;
                                });
                              },
                            ),
                            prefixIcon: const Icon(Icons.lock),
                            hintText: "Mot de passe"),
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                              top: 15,
                              bottom: 15,
                            ),
                            child: Text(
                              'Mot de passe oublié ?',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Center(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 55,
                                  width: 350,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[700],
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                    onPressed: _signIn,
                                    child: const Text(
                                      'Connexion',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      SizedBox(
                                        height: 0.3,
                                        width: 100,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                              color: Colors.black),
                                        ),
                                      ),
                                      const Text('OU'),
                                      SizedBox(
                                        height: 0.3,
                                        width: 100,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                              color: Colors.black),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                  " Vous n'avez pas encore de compte ? "),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacementNamed(
                                      context, '/signup');
                                },
                                child: Text(
                                  "Je m'inscris",
                                  style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
