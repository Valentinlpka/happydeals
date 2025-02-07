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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReferralDetailPage(referralId: referral.id),
              ),
            );
          },
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
                            'Parrainage #${referral.id.substring(0, 6)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy à HH:mm')
                                .format(referral.timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(referral.status),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.store_outlined,
                            size: 18,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              referral.companyName,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 18,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              referral.type == 'sponsorship'
                                  ? 'Filleul: ${referral.refereeName}'
                                  : 'Parrain: ${referral.sponsorName}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'Validé':
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        text = 'Validé';
        icon = Icons.check_circle_outline;
        break;
      case 'Refusé':
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        text = 'Refusé';
        icon = Icons.cancel_outlined;
        break;
      case 'En cours':
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        text = 'En cours';
        icon = Icons.hourglass_empty;
        break;
      case 'Envoyé':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        text = 'Envoyé';
        icon = Icons.send_outlined;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        text = status;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
