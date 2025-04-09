import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/cards/concours_card.dart';

class MyContestsPage extends StatelessWidget {
  final String userId;

  const MyContestsPage({required this.userId, super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const CustomAppBar(
          title: 'Mes Jeux Concours',
          align: Alignment.center,
          bottom: TabBar(
            tabs: [
              Tab(text: 'En cours'),
              Tab(text: 'Gagnés'),
              Tab(text: 'Terminés'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ContestsList(
              userId: userId,
              status: ContestStatus.active,
            ),
            _ContestsList(
              userId: userId,
              status: ContestStatus.won,
            ),
            _ContestsList(
              userId: userId,
              status: ContestStatus.ended,
            ),
          ],
        ),
      ),
    );
  }
}

enum ContestStatus { active, won, ended }

class _ContestsList extends StatelessWidget {
  final String userId;
  final ContestStatus status;

  const _ContestsList({
    required this.userId,
    required this.status,
  });

  Future<Map<String, dynamic>> _fetchCompanyInfo(String companyId) async {
    final doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();
    return {
      'name': doc.data()?['name'] ?? '',
      'logo': doc.data()?['logo'] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getContestsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) print(snapshot.error);
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final contests = snapshot.data?.docs
                .map((doc) => Contest.fromDocument(doc))
                .toList() ??
            [];

        if (contests.isEmpty) {
          return const Center(
            child: Text('Aucun jeu concours dans cette catégorie'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: contests.length,
          itemBuilder: (context, index) {
            final contest = contests[index];
            return FutureBuilder<Map<String, dynamic>>(
              future: _fetchCompanyInfo(contest.companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()));
                }

                final companyInfo = snapshot.data ?? {'name': '', 'logo': ''};

                return ConcoursCard(
                  contest: contest,
                  currentUserId: userId,
                );
              },
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getContestsStream() {
    var query = FirebaseFirestore.instance
        .collection('posts')
        .where('type', isEqualTo: 'contest');

    switch (status) {
      case ContestStatus.active:
        return query
            .where('endDate', isGreaterThan: Timestamp.now())
            .snapshots();
      case ContestStatus.won:
        return query.where('winner.userId', isEqualTo: userId).snapshots();
      case ContestStatus.ended:
        return query.where('endDate', isLessThan: Timestamp.now()).snapshots();
    }
  }
}
