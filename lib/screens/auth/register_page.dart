import 'package:flutter/material.dart';
import '../../auth_service.dart';

class Register extends StatefulWidget {
  final Function()? onTap;
  const Register({
    Key? key,
    this.onTap,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _RegisterState createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(hintText: 'Username'),
                ),
              ),
              const SizedBox(
                height: 30.0,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(hintText: 'Email'),
                ),
              ),
              const SizedBox(
                height: 30.0,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Password',
                  ),
                ),
              ),
              const SizedBox(
                height: 30.0,
              ),
              ElevatedButton(
                onPressed: () async {
                  final message = await AuthService().registration(
                    username: _usernameController.text,
                    email: _emailController.text,
                    password: _passwordController.text,
                  );
                  if (message!.contains('Success') && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Compte créer avec succès'),
                      ),
                    );
                  }
                },
                child: const Text('Create Account'),
              ),
              ElevatedButton(
                onPressed: widget.onTap,
                child: const Text('Me connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
