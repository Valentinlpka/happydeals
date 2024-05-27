import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final user = FirebaseAuth.instance.currentUser!;

  void signOut() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const CircleAvatar(
              radius: 46,
              backgroundColor: Colors.blueGrey,
              child: CircleAvatar(
                radius: 44,
                backgroundImage: NetworkImage(
                    'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
              ),
            ),
            Text(
              'Valentin Lipka ${user.email}${user.displayName}',
            ),
            ElevatedButton(onPressed: signOut, child: const Text('Déconnexion'))
          ],
        ),
      ),
    );
  }
}
