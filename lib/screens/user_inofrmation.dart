import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/widgets/company_card.dart';

class UserInformation extends StatefulWidget {
  const UserInformation({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _UserInformationState createState() => _UserInformationState();
}

class _UserInformationState extends State<UserInformation> {
  final Stream<QuerySnapshot> _usersStream =
      FirebaseFirestore.instance.collection('companys').snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading");
        }

        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            Map<String, dynamic> data =
                document.data()! as Map<String, dynamic>;

// Compter les likes de l'entreprise
            List<dynamic> likedBy = data['liked_by'] ?? [];
            int likeCount = likedBy.length;

            return CompanyCard(Company(
              id: document.id,
              name: data['name'],
              categorie: data['categorie'],
              open: false,
              rating: 4,
              like: likeCount,
              ville: data['adress']['ville'],
              phone: data['phone'],
              logo: '',
              description: '',
              website: '',
              address: '',
              email: '',
            ));
          }).toList(),
        );
      },
    );
  }
}
