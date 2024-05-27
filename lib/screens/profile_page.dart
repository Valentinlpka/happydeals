import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatelessWidget {
  ProfilePage({super.key});

  final user = FirebaseAuth.instance.currentUser!;

  void RecupInfos() async {
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    print(userData.data()!['uid']);
  }

  void SignOut() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    String imageUrl;
    RecupInfos();
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: Colors.blueGrey,
              child: CircleAvatar(
                radius: 44,
                backgroundImage: NetworkImage(
                    'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
              ),
            ),
            Text(
              'Valentin Lipka' +
                  ' ' +
                  user.email.toString() +
                  user.displayName.toString(),
            ),
            ElevatedButton(onPressed: SignOut, child: Text('Déconnexion'))
          ],
        ),
      ),
    );
  }
}
