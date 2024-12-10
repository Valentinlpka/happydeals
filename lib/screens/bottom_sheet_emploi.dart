import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/post_type_page/job_search_profile_page.dart';

class ApplicationBottomSheet extends StatefulWidget {
  final String jobOfferId;
  final String companyId;

  const ApplicationBottomSheet({
    super.key,
    required this.jobOfferId,
    required this.companyId,
  });

  @override
  _ApplicationBottomSheetState createState() => _ApplicationBottomSheetState();
}

class _ApplicationBottomSheetState extends State<ApplicationBottomSheet> {
  bool _isLoading = false;
  bool _hasApplied = false;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkExistingApplication();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userData.exists) {
        setState(() {
          _userData = userData.data() ?? {};
        });
      }
    }
  }

  Future<void> _checkExistingApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final existingApplication = await FirebaseFirestore.instance
          .collection('applications')
          .where('applicantId', isEqualTo: user.uid)
          .where('jobOfferId', isEqualTo: widget.jobOfferId)
          .get();

      setState(() {
        _hasApplied = existingApplication.docs.isNotEmpty;
      });

      if (_hasApplied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vous avez déjà postulé à cette offre.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _submitApplication() async {
    if (_hasApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous avez déjà postulé à cette offre.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      DocumentSnapshot jobSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.jobOfferId)
          .get();
      Map<String, dynamic> jobData = jobSnapshot.data() as Map<String, dynamic>;

      DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
          .collection('companys')
          .doc(jobData['companyId'])
          .get();
      Map<String, dynamic> companyData =
          companySnapshot.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference applicationRef =
            FirebaseFirestore.instance.collection('applications').doc();

        transaction.set(applicationRef, {
          'jobOfferId': widget.jobOfferId,
          'companyId': widget.companyId,
          'jobTitle': jobData['job_title'],
          'companyName': companyData['name'],
          'companyLogo': companyData['logo'],
          'applicantId': FirebaseAuth.instance.currentUser!.uid,
          'name': _userData['name'],
          'email': _userData['email'],
          'phone': _userData['phone'],
          'cvUrl': _userData['cvUrl'],
          'cvFileName': _userData['cvFileName'],
          'status': 'pending',
          'appliedAt': FieldValue.serverTimestamp(),
        });

        DocumentReference notificationRef =
            FirebaseFirestore.instance.collection('notifications').doc();
        transaction.set(notificationRef, {
          'userId': widget.companyId,
          'type': 'new_application',
          'message':
              'Nouvelle candidature pour le poste ${jobData['job_title']} de ${_userData['name']}',
          'relatedId': applicationRef.id,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidature envoyée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'envoi de la candidature'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Postuler maintenant',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 20),
            if (_hasApplied)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Vous avez déjà postulé à cette offre.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            _buildInfoTile(
                'Nom',
                _userData['firstName'] + ' ' + _userData['lastName'] ??
                    'Non renseigné'),
            _buildInfoTile('Email', _userData['email'] ?? 'Non renseigné'),
            _buildInfoTile('Téléphone', _userData['phone'] ?? 'Non renseigné'),
            _buildInfoTile('CV', _userData['cvFileName'] ?? 'Non renseigné'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed:
                      _hasApplied || _isLoading ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _hasApplied ? Colors.grey : Colors.blue[800],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _hasApplied ? 'Déjà postulé' : 'Postuler à l\'offre'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const JobSearchProfilePage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Modifier mes informations'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
