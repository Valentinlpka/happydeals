import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/login_or_register.dart';
import 'package:happy/screens/main_container.dart';
import 'package:provider/provider.dart';

import '../../providers/users.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: ((_, snapshot) {
          if (snapshot.hasData) {
            context.read<Users>().login();
            return const MainContainer();
          } else {
            context.read<Users>().logout();
            return const LoginOrRegisterPage();
          }
        }),
      ),
    );
  }
}
