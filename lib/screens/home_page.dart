import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:happy/widgets/search_bar_home.dart';
import 'package:happy/widgets/buttons_categories.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final String currentUserId =
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.all(
                        Radius.circular(50),
                      ),
                      child: Image(
                        image: NetworkImage(
                            "https://media.licdn.com/dms/image/D4E03AQFMHad2UnXwvQ/profile-displayphoto-shrink_800_800/0/1675073860682?e=2147483647&v=beta&t=BZqJ7LPv-gg9Ehm-fVDmrl4QUi0_Oc2bHVjLuvpdIrc"),
                        height: 54,
                        width: 54,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: 12),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Salut Valentin !",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Petite phrase différente chaque jour",
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: SizedBox(
                    width: size.width,
                    child: const SearchBarHome(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {},
                          child: const ButtonCategories(
                              Icons.people_outlined, 'Annuaire'),
                        ),
                        const ButtonCategories(Icons.people_outlined, 'Deals'),
                        const ButtonCategories(
                            Icons.people_outlined, 'Action Spéciales'),
                        const ButtonCategories(
                            Icons.people_outlined, 'Brocante'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (BuildContext context,
                      AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.hasError) {
                      return const Text('Something went wrong');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No posts available'));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        DocumentSnapshot document = snapshot.data!.docs[index];
                        Map<String, dynamic>? data =
                            document.data() as Map<String, dynamic>?;

                        if (data == null) {
                          return const SizedBox.shrink();
                        }

                        Post post;
                        switch (data['type']) {
                          case 'job_offer':
                            post = JobOffer.fromDocument(document);
                            break;
                          case 'contest':
                            post = Contest.fromDocument(document);
                            break;
                          case 'express_deal':
                            post = ExpressDeal.fromDocument(document);
                            break;
                          case 'event':
                            post = Event.fromDocument(document);
                            break;
                          case 'happy_deal':
                            post = HappyDeal.fromDocument(document);
                            break;
                          case 'referral':
                            post = Referral.fromDocument(document);
                            break;
                          default:
                            return const SizedBox.shrink();
                        }

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('companys')
                              .doc(data['companyId'])
                              .get(),
                          builder: (BuildContext context,
                              AsyncSnapshot<DocumentSnapshot> companySnapshot) {
                            if (companySnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (companySnapshot.hasError) {
                              return const Text('Error loading company data');
                            }
                            if (!companySnapshot.hasData ||
                                !companySnapshot.data!.exists) {
                              return const Text('Company not found');
                            }

                            Map<String, dynamic>? companyData =
                                companySnapshot.data!.data()
                                    as Map<String, dynamic>?;

                            if (companyData == null) {
                              return const SizedBox.shrink();
                            }

                            return PostWidget(
                              key: Key(document.id),
                              post: post,
                              companyCategorie: companyData['categorie'] ?? '',
                              companyName: companyData['name'] ?? 'Unknown',
                              companyLogo: companyData['logo'] ?? '',
                              currentUserId: currentUserId,
                              onView: () {
                                // Logique d'affichage
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
