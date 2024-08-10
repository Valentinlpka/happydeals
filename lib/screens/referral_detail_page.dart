import 'package:flutter/material.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/user_referral.dart';
import 'package:happy/services/referral_services.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';
import 'package:intl/intl.dart';

class ReferralDetailPage extends StatefulWidget {
  final String referralId;

  const ReferralDetailPage({super.key, required this.referralId});

  @override
  _ReferralDetailPageState createState() => _ReferralDetailPageState();
}

class _ReferralDetailPageState extends State<ReferralDetailPage> {
  final ReferralService _referralService = ReferralService();
  late Future<Map<String, dynamic>> _referralDataFuture;

  @override
  void initState() {
    super.initState();
    _referralDataFuture = _loadReferralData();
  }

  Future<Map<String, dynamic>> _loadReferralData() async {
    final userReferral =
        await _referralService.getUserReferral(widget.referralId);
    final referral =
        await _referralService.getReferralPost(userReferral.referralId);
    final companyInfo =
        await _referralService.getCompanyInfo(referral.companyId);

    return {
      'userReferral': userReferral,
      'referral': referral,
      'companyName': companyInfo['companyName'],
      'companyLogo': companyInfo['companyLogo'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du parrainage',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _referralDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Une erreur est survenue: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Parrainage non trouvé'));
          }

          final userReferral = snapshot.data!['userReferral'] as UserReferral;
          final referral = snapshot.data!['referral'] as Referral;
          final companyName = snapshot.data!['companyName'] as String;
          final companyLogo = snapshot.data!['companyLogo'] as String;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ParrainageCard(
                  post: referral,
                  companyLogo: companyLogo,
                  companyName: companyName,
                  currentUserId: userReferral.sponsorUid,
                ),
                const SizedBox(height: 24),
                _buildInfoSection('Informations du filleul', [
                  'Nom: ${userReferral.refereeName}',
                  'Contact: ${userReferral.refereeContact}',
                  'Type de contact: ${userReferral.refereeContactType}',
                ]),
                const SizedBox(height: 24),
                _buildInfoSection('Informations du parrain', [
                  'Nom: ${userReferral.sponsorName}',
                  'Email: ${userReferral.sponsorEmail}',
                ]),
                const SizedBox(height: 24),
                _buildInfoSection('Message', [userReferral.message]),
                const SizedBox(height: 24),
                _buildInfoSection('Détails du parrainage', [
                  'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(userReferral.timestamp)}',
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(String title, List<String> infos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...infos.map((info) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(info),
            )),
      ],
    );
  }
}
