import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/user_referral.dart';
import 'package:happy/screens/referral_detail_page.dart';
import 'package:happy/services/referral_services.dart';
import 'package:intl/intl.dart';

class UserReferralsPage extends StatefulWidget {
  const UserReferralsPage({super.key});

  @override
  _UserReferralsPageState createState() => _UserReferralsPageState();
}

class _UserReferralsPageState extends State<UserReferralsPage> {
  final ReferralService _referralService = ReferralService();
  late Future<List<UserReferral>> _referralsFuture;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _referralsFuture = _referralService.getUserReferrals(user.uid);
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Chargez plus de parrainages ici si nécessaire
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes parrainages',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<List<UserReferral>>(
        future: _referralsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print(snapshot.error);
            return const Center(child: Text('Une erreur est survenue'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Vous n\'avez pas encore de parrainages'));
          }

          return ListView.builder(
            controller: _scrollController,
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final referral = snapshot.data![index];
              return _buildReferralCard(referral);
            },
          );
        },
      ),
    );
  }

  Widget _buildReferralCard(UserReferral referral) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      child: InkWell(
        onTap: () {
          print(referral.referralId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReferralDetailPage(
                referralId: referral.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filleul: ${referral.refereeName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Contact: ${referral.refereeContact} (${referral.refereeContactType})',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(referral.timestamp)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
