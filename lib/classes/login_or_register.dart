import 'package:flutter/material.dart';
import 'package:happy/screens/auth/register_page.dart';

import '../screens/auth/login_page.dart';

class LoginOrRegisterPage extends StatefulWidget {
  const LoginOrRegisterPage({super.key});

  @override
  State<LoginOrRegisterPage> createState() => _LoginOrRegisterPageState();
}

class _LoginOrRegisterPageState extends State<LoginOrRegisterPage> {
  bool showLoginPage = false;
  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return Register(onTap: togglePages);
    } else {
      return Login(onTap: togglePages);
    }
  }
}
