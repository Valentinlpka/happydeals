import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/user_referral.dart';
import 'package:happy/screens/referral_detail_page.dart';
import 'package:happy/services/referral_services.dart';
import 'package:happy/widgets/company_selector_referral.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:intl/intl.dart';

class UserReferralsPage extends StatefulWidget {
  const UserReferralsPage({super.key});

  @override
  _UserReferralsPageState createState() => _UserReferralsPageState();
}

class _UserReferralsPageState extends State<UserReferralsPage> {
  final ReferralService _referralService = ReferralService();
  late Future<List<UserReferral>> _sentReferralsFuture;
  late Future<List<UserReferral>> _receivedReferralsFuture;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _sentReferralsFuture = _referralService.getUserReferrals(
          user.uid, 'sponsorship', 'sponsorUid');
      _receivedReferralsFuture = _referralService.getUserReferrals(
          user.uid, 'sponsorship_request', 'refereeUid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarBack(
        title: 'Mes parrainages',
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CompanyReferralButton(),
            _buildReferralSection(
              title: 'Parrainages envoyés',
              future: _sentReferralsFuture,
              emptyMessage: 'Vous n\'avez pas encore envoyé de parrainages',
            ),
            _buildReferralSection(
              title: 'Parrainages reçus',
              future: _receivedReferralsFuture,
              emptyMessage: 'Vous n\'avez pas encore reçu de parrainages',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralSection({
    required String title,
    required Future<List<UserReferral>> future,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        FutureBuilder<List<UserReferral>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              print(snapshot.error);
              return Center(
                  child: Text('Une erreur est survenue: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text(emptyMessage));
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final referral = snapshot.data![index];
                return _buildReferralCard(referral);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildReferralCard(UserReferral referral) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entreprise: ${referral.companyName}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        referral.type == 'sponsorship'
                            ? 'Filleul: ${referral.refereeName}'
                            : 'Parrain: ${referral.sponsorName}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(referral.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(referral.status),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(referral.timestamp),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReferralDetailPage(referralId: referral.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Voir en détail'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Envoyé':
        return Colors.blue;
      case 'En cours':
        return Colors.orange;
      case 'Refusé':
        return Colors.red;
      case 'Validé':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Envoyé':
        return 'Envoyé';
      case 'En cours':
        return 'En cours';
      case 'Refusé':
        return 'Refusé';
      case 'Validé':
        return 'Validé';
      default:
        return 'Inconnu';
    }
  }
}
