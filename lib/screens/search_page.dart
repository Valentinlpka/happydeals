import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/happydeal.dart';

addSamplePosts() async {
  final CollectionReference posts =
      FirebaseFirestore.instance.collection('posts');

  final happydeal = HappyDeal(
    id: 'deal123',
    timestamp: DateTime.now(),
    authorId: 'author123',
    title: 'Super Happy Deal',
    description: 'Profitez de nos super offres!',
    deals: [
      Deal(name: 'Spa 2 personnes', oldPrice: 100.0, newPrice: 50.0),
      Deal(name: 'Massage', oldPrice: 60.0, newPrice: 30.0),
    ],
    startDate: DateTime.now(),
    endDate: DateTime.now().add(const Duration(days: 5)),
    companyId: 'company123',
    photo: 'https://example.com/photo.jpg',
  );

  await posts.add(happydeal.toMap());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  addSamplePosts();
  runApp(const Search());

  // Ajouter des exemples de posts
}

class Search extends StatelessWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Sample Posts'),
        ),
        body: const Center(
          child: Column(
            children: [
              ElevatedButton(onPressed: addSamplePosts, child: Text('BB')),
              Text('Check your Firestore database for sample posts.'),
            ],
          ),
        ),
      ),
    );
  }
}
