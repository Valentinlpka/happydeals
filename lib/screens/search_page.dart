import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/referral.dart';

addSamplePosts() async {
  final CollectionReference posts =
      FirebaseFirestore.instance.collection('posts');

  final DateTime now = DateTime.now();

  final contest = Contest(
    id: '',
    timestamp: now,
    authorId: 'author1',
    title: 'Grand Concours',
    description: 'Participez pour gagner de superbes cadeaux!',
    gifts: ['Gift 1', 'Gift 2'],
    companyId: 'company1',
    howToParticipate: 'Achetez pour 50€ et participez au tirage au sort',
    conditions: 'Conditions de participation...',
    startDate: now,
    endDate: now.add(Duration(days: 7)),
    giftPhoto: 'https://example.com/photo.jpg',
  );

  final expressDeal = ExpressDeal(
    id: '',
    timestamp: now,
    authorId: 'author2',
    basketType: 'Panier de légumes',
    pickupTime: now.add(Duration(hours: 2)),
    content: 'Un panier de légumes frais',
    companyId: 'company2',
    basketCount: 10,
  );

  final event = Event(
    id: '',
    timestamp: now,
    authorId: 'author3',
    title: 'Concert de Jazz',
    category: 'Musique',
    eventDate: now.add(Duration(days: 1)),
    city: 'Paris',
    description: 'Un concert de jazz à ne pas manquer',
    companyId: 'company3',
    products: ['Product 1', 'Product 2'],
    photo: 'https://example.com/photo.jpg',
  );

  final happyDeal = HappyDeal(
    id: '',
    timestamp: now,
    authorId: 'author4',
    title: 'Happy Deal de la semaine',
    description: 'Des réductions incroyables!',
    deals: ['Deal 1', 'Deal 2'],
    startDate: now,
    endDate: now.add(Duration(days: 7)),
    companyId: 'company4',
    photo: 'https://example.com/photo.jpg',
  );

  final jobOffer = JobOffer(
    id: '',
    timestamp: now,
    authorId: 'author5',
    jobTitle: 'Développeur Flutter',
    city: 'Lyon',
    description: 'Rejoignez notre équipe dynamique',
    missions: 'Développer des applications mobiles',
    profile: 'Expérience en Flutter requise',
    benefits: 'Tickets restaurant, Mutuelle',
    whyJoin: 'Ambiance startup, projets innovants',
    keywords: ['Flutter', 'Mobile'],
    companyId: 'company5',
  );

  final referral = Referral(
    id: '',
    timestamp: now,
    authorId: 'author6',
    title: 'Programme de Parrainage',
    description: 'Parrainez un ami et recevez des récompenses',
    sponsorBenefit: '10€ de réduction pour le parrain',
    refereeBenefit: '10€ de réduction pour le filleul',
    companyId: 'company6',
    image: 'https://example.com/photo.jpg',
  );

  // Add the documents to Firestore
  await posts.add(contest.toMap());
  await posts.add(expressDeal.toMap());
  await posts.add(event.toMap());
  await posts.add(happyDeal.toMap());
  await posts.add(jobOffer.toMap());
  await posts.add(referral.toMap());

  print('Sample posts added successfully.');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  addSamplePosts();
  runApp(Search());

  // Ajouter des exemples de posts
}

class Search extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Sample Posts'),
        ),
        body: Center(
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
