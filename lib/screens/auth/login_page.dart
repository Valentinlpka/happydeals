import 'package:flutter/material.dart';
import '../../auth_service.dart';

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

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

// Fonction pour se connecteur a firebase

  void signUserIn() async {
    showDialog(
        context: context,
        builder: (context) {
          return const Center(child: CircularProgressIndicator());
        });

    final message = await AuthService().login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (mounted) {
      if (message!.contains('Success')) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            content: Text('Connexion réussi !'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            content: Text(message),
          ),
        );
      }
      Navigator.pop(context);
    }
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
                Image.network(
                    height: 150,
                    'https://happy-deals.fr/wp-content/uploads/2022/07/HAPPY-DEALS-1.png'),
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
                        crossAxisAlignment: CrossAxisAlignment.end,
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
                                    onPressed: signUserIn,
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
                          Padding(
                            padding: const EdgeInsets.only(top: 14.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                    " Vous n'avez pas encore de compte ? "),
                                GestureDetector(
                                  onTap: widget.onTap,
                                  child: Text(
                                    "Je m'inscris",
                                    style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
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
