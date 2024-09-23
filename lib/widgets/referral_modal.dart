// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// class ReferralModal extends StatefulWidget {
//   final String referralId;
//   final String companyId;

//   const ReferralModal(
//       {super.key, required this.referralId, required this.companyId});

//   @override
//   _ReferralModalState createState() => _ReferralModalState();
// }

// class _ReferralModalState extends State<ReferralModal> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _contactController = TextEditingController();
//   final _messageController = TextEditingController();
//   String _contactType = 'email';

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Parrainage',
//               style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 20),
//             TextFormField(
//               controller: _nameController,
//               decoration: const InputDecoration(
//                 labelText: 'Nom et prénom',
//                 border: OutlineInputBorder(),
//               ),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Veuillez entrer un nom et prénom';
//                 }
//                 return null;
//               },
//             ),
//             const SizedBox(height: 10),
//             DropdownButtonFormField<String>(
//               value: _contactType,
//               decoration: const InputDecoration(
//                 labelText: 'Type de contact',
//                 border: OutlineInputBorder(),
//               ),
//               items: const [
//                 DropdownMenuItem(value: 'email', child: Text('Email')),
//                 DropdownMenuItem(value: 'phone', child: Text('Téléphone')),
//               ],
//               onChanged: (value) {
//                 setState(() {
//                   _contactType = value!;
//                 });
//               },
//             ),
//             const SizedBox(height: 10),
//             TextFormField(
//               controller: _contactController,
//               decoration: InputDecoration(
//                 labelText:
//                     _contactType == 'email' ? 'Email' : 'Numéro de téléphone',
//                 border: const OutlineInputBorder(),
//               ),
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'Veuillez entrer une information de contact';
//                 }
//                 return null;
//               },
//             ),
//             const SizedBox(height: 10),
//             TextFormField(
//               controller: _messageController,
//               decoration: const InputDecoration(
//                 labelText: 'Message',
//                 border: OutlineInputBorder(),
//               ),
//               maxLines: 3,
//             ),
//             const SizedBox(height: 20),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue[800],
//                   padding: const EdgeInsets.symmetric(vertical: 15),
//                 ),
//                 onPressed: _submitReferral,
//                 child: const Text('Envoyer'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _submitReferral() async {
//     if (_formKey.currentState!.validate()) {
//       try {
//         final user = FirebaseAuth.instance.currentUser;
//         if (user != null) {
//           final userDoc = await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .get();
//           final userData = userDoc.data() as Map<String, dynamic>;

//           // Créer une référence pour la transaction
//           final referralRef =
//               FirebaseFirestore.instance.collection('referrals').doc();
//           final notificationRef =
//               FirebaseFirestore.instance.collection('notifications').doc();

//           // Utiliser une transaction pour garantir que les deux opérations réussissent ou échouent ensemble
//           await FirebaseFirestore.instance.runTransaction((transaction) async {
//             // Créer le parrainage
//             transaction.set(referralRef, {
//               'referralId': widget.referralId,
//               'sponsorUid': user.uid,
//               'companyId': widget.companyId,
//               'sponsorName': '${userData['firstName']} ${userData['lastName']}',
//               'sponsorEmail': userData['email'],
//               'refereeName': _nameController.text,
//               'refereeContactType': _contactType,
//               'refereeContact': _contactController.text,
//               'message': _messageController.text,
//               'timestamp': FieldValue.serverTimestamp(),
//             });

//             // Créer la notification
//             transaction.set(notificationRef, {
//               'userId': widget
//                   .companyId, // L'ID de l'entreprise qui recevra la notification
//               'type': 'new_referral',
//               'message':
//                   'Nouveau parrainage soumis par ${userData['firstName']} ${userData['lastName']}',
//               'relatedId': referralRef.id,
//               'timestamp': FieldValue.serverTimestamp(),
//               'isRead': false,
//             });
//           });

//           Navigator.of(context).pop();
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Parrainage enregistré avec succès!')),
//           );
//         }
//       } catch (e) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content:
//                   Text('Erreur lors de l\'enregistrement du parrainage: $e')),
//         );
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _nameController.dispose();
//     _contactController.dispose();
//     _messageController.dispose();
//     super.dispose();
//   }
// }
