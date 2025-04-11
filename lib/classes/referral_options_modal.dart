import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserService {
  static Future<String?> getUserUniqueCode(String userId) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data()?['uniqueCode'];
  }

  static Future<Map<String, dynamic>?> getUserByUniqueCode(
      String uniqueCode) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('uniqueCode', isEqualTo: uniqueCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data();
    }
    return null;
  }
}

class ReferralOptionsModal extends StatelessWidget {
  final String companyId;
  final String referralId;

  const ReferralOptionsModal(
      {super.key, required this.companyId, required this.referralId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choisissez une option',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildOptionButton(
            context,
            'Je parraine',
            () => _showReferralModal(context),
          ),
          const SizedBox(height: 10),
          _buildOptionButton(
            context,
            'Je souhaite être parrainé',
            () => _showSponsorshipRequestModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton(
      BuildContext context, String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  void _showReferralModal(BuildContext context) {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ReferralModal(
              companyId: companyId,
              referralId: referralId,
            ),
          ),
        );
      },
    );
  }

  void _showSponsorshipRequestModal(BuildContext context) {
    Navigator.of(context).pop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SponsorshipRequestModal(
              companyId: companyId,
              referralId: referralId,
            ),
          ),
        );
      },
    );
  }
}

class ReferralModal extends StatefulWidget {
  final String referralId;
  final String companyId;

  const ReferralModal(
      {super.key, required this.companyId, required this.referralId});

  @override
  State<ReferralModal> createState() => _ReferralModalState();
}

class _ReferralModalState extends State<ReferralModal> {
  final _formKey = GlobalKey<FormState>();
  final _refereeCodeController = TextEditingController();
  final _messageController = TextEditingController();
  String _contactPreference = 'email';
  double _urgencyLevel = 4;
  Map<String, dynamic>? _refereeData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Je parraine',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _refereeCodeController,
              decoration: InputDecoration(
                labelText: 'Code unique du filleul',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchReferee,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le code unique du filleul';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _searchReferee,
              child: const Text('Rechercher le filleul'),
            ),
            if (_refereeData != null) ...[
              const SizedBox(height: 10),
              Text(
                  'Filleul: ${_refereeData!['firstName']} ${_refereeData!['lastName']}'),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _contactPreference,
                decoration: const InputDecoration(
                  labelText: 'Préférence de contact',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'email', child: Text('Par email')),
                  DropdownMenuItem(
                      value: 'phone', child: Text('Par téléphone')),
                  DropdownMenuItem(
                      value: 'direct',
                      child: Text('Il contactera directement l\'entreprise')),
                ],
                onChanged: (value) {
                  setState(() {
                    _contactPreference = value!;
                  });
                },
              ),
              const SizedBox(height: 10),
              if (_contactPreference == 'email')
                Text(
                    'Email de contact: ${_refereeData!['email'] ?? 'Non disponible'}'),
              if (_contactPreference == 'phone')
                Text(
                    'Téléphone de contact: ${_refereeData!['phone'] ?? 'Non disponible'}'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              Text('Urgence de la demande: ${_urgencyLevel.round()}'),
              Slider(
                value: _urgencyLevel,
                min: 1,
                max: 7,
                divisions: 6,
                label: _urgencyLevel.round().toString(),
                onChanged: (value) {
                  setState(() {
                    _urgencyLevel = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _submitReferral,
                  child: const Text('Envoyer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _searchReferee() async {
    if (_refereeCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un code de filleul')),
      );
      return;
    }

    final refereeData =
        await UserService.getUserByUniqueCode(_refereeCodeController.text);
    setState(() {
      _refereeData = refereeData;
      if (refereeData != null) {
        _contactPreference = 'email';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun filleul trouvé avec ce code')),
        );
      }
    });
  }

  void _submitReferral() async {
    if (_formKey.currentState!.validate() && _refereeData != null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && context.mounted) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          final userData = userDoc.data() as Map<String, dynamic>;

          final sponsorCode = _refereeCodeController.text;
          final refereeDoc = await FirebaseFirestore.instance
              .collection('users')
              .where('uniqueCode', isEqualTo: sponsorCode)
              .limit(1)
              .get();

          final refereeData = refereeDoc.docs.first.data();

          final companyDoc = await FirebaseFirestore.instance
              .collection('companys')
              .doc(widget.companyId)
              .get();
          final companyName = companyDoc.data()?['name'] ?? 'Nom inconnu';

          final referralRef =
              FirebaseFirestore.instance.collection('referrals').doc();
          final notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            transaction.set(referralRef, {
              'referralId': widget.referralId,
              'sponsorUid': user.uid,
              'companyName': companyName,
              'refereeUid': refereeDoc.docs[0].id,
              'companyId': widget.companyId,
              'sponsorName': '${userData['firstName']} ${userData['lastName']}',
              'sponsorEmail': userData['email'],
              'refereeName':
                  '${refereeData['firstName']} ${refereeData['lastName']}',
              'refereeContactType': _contactPreference,
              'refereeContact':
                  '${refereeData['email']} ${refereeData['phone']}',
              'message': _messageController.text,
              'urgencyLevel': _urgencyLevel,
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'sponsorship',
              'status': 'Envoyé'
            });

            transaction.set(notificationRef, {
              'userId': widget.companyId,
              'type': 'new_referral',
              'message':
                  'Nouveau parrainage soumis par ${userData['firstName']} ${userData['lastName']}',
              'relatedId': referralRef.id,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          });
          if (!mounted) return;
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parrainage enregistré avec succès!')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Erreur lors de l\'enregistrement du parrainage: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _refereeCodeController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

class SponsorshipRequestModal extends StatefulWidget {
  final String companyId;
  final String referralId;

  const SponsorshipRequestModal(
      {super.key, required this.companyId, required this.referralId});

  @override
  State<SponsorshipRequestModal> createState() =>
      _SponsorshipRequestModalState();
}

class _SponsorshipRequestModalState extends State<SponsorshipRequestModal> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _sponsorIdController = TextEditingController();
  double _urgencyLevel = 4;
  Map<String, dynamic>? _sponsorData;
  String _contactPreference = 'email';
  String? _userEmail;
  String? _userPhone;
  String? _userFirstName;
  String? _userLastName;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _userEmail = userData.data()?['email'];
        _userPhone = userData.data()?['phone'];
        _userLastName = userData.data()?['lastName'];
        _userFirstName = userData.data()?['firstName'];
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Je souhaite être parrainé',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _sponsorIdController,
              decoration: InputDecoration(
                labelText: 'Code unique du parrain',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchSponsor,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer le code unique du parrain';
                }
                return null;
              },
            ),
            if (_sponsorData != null) ...[
              const SizedBox(height: 10),
              Text(
                  'Parrain: ${_sponsorData!['firstName']} ${_sponsorData!['lastName']}'),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _contactPreference,
              decoration: const InputDecoration(
                labelText: 'Préférence de contact',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'email', child: Text('Par email')),
                DropdownMenuItem(value: 'phone', child: Text('Par téléphone')),
                DropdownMenuItem(
                    value: 'direct',
                    child: Text('Je contacterai directement l\'entreprise')),
              ],
              onChanged: (value) {
                setState(() {
                  _contactPreference = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            if (_contactPreference == 'email')
              Text('Email de contact: $_userEmail'),
            if (_contactPreference == 'phone')
              Text('Téléphone de contact: $_userPhone'),
            const SizedBox(height: 10),
            Text('Urgence de la demande: ${_urgencyLevel.round()}'),
            Slider(
              value: _urgencyLevel,
              min: 1,
              max: 7,
              divisions: 6,
              label: _urgencyLevel.round().toString(),
              onChanged: (value) {
                setState(() {
                  _urgencyLevel = value;
                });
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _submitSponsorshipRequest,
                child: const Text('Envoyer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _searchSponsor() async {
    final sponsorData =
        await UserService.getUserByUniqueCode(_sponsorIdController.text);
    setState(() {
      _sponsorData = sponsorData;
    });
  }

  void _submitSponsorshipRequest() async {
    if (_formKey.currentState!.validate() && _sponsorData != null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final refereeDoc = await FirebaseFirestore.instance
              .collection('users')
              .where('uniqueCode', isEqualTo: _sponsorIdController.text)
              .limit(1)
              .get();

          final refereeData = refereeDoc.docs.first.data();

          // Récupérer le nom de l'entreprise
          final companyDoc = await FirebaseFirestore.instance
              .collection('companys')
              .doc(widget.companyId)
              .get();
          final companyName = companyDoc.data()?['name'] ?? 'Nom inconnu';

          final referralRef =
              FirebaseFirestore.instance.collection('referrals').doc();
          final notificationRef =
              FirebaseFirestore.instance.collection('notifications').doc();

          await FirebaseFirestore.instance.runTransaction((transaction) async {
            transaction.set(referralRef, {
              'referralId': widget.referralId,
              'sponsorUid': user.uid,
              'companyId': widget.companyId,
              'companyName': companyName,
              'refereeUid': refereeDoc.docs[0].id,
              'sponsorName':
                  '${refereeData['firstName']} ${refereeData['lastName']}',
              'sponsorEmail': refereeData['email'],
              'refereeName': '$_userFirstName $_userLastName',
              'refereeContactType': _contactPreference,
              'refereeContact': '$_userEmail $_userPhone',
              'message': _messageController.text,
              'urgencyLevel': _urgencyLevel,
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'sponsorship_request',
              'etat': 'envoyé'
            });

            transaction.set(notificationRef, {
              'userId': _sponsorData!['uid'],
              'type': 'new_sponsorship_request',
              'message':
                  'Nouvelle demande de parrainage de ${user.displayName ?? 'un utilisateur'}',
              'relatedId': referralRef.id,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          });
          if (!mounted) return;

          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Demande de parrainage enregistrée avec succès!')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Erreur lors de l\'enregistrement de la demande de parrainage: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _sponsorIdController.dispose();
    super.dispose();
  }
}
