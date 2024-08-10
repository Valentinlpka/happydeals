import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/modify_application_page.dart';
import 'package:intl/intl.dart';

class UserApplicationsPage extends StatelessWidget {
  const UserApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes candidatures'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('applications')
            .where('applicantId', isEqualTo: user != null ? user.uid : '')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune candidature trouvée'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var application = snapshot.data!.docs[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(application['jobOfferId'])
                    .get(),
                builder: (context, jobSnapshot) {
                  if (jobSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                        child: ListTile(title: Text('Chargement...')));
                  }

                  if (jobSnapshot.hasError || !jobSnapshot.hasData) {
                    return const Card(
                        child: ListTile(title: Text('Erreur de chargement')));
                  }

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: CircleAvatar(
                        maxRadius: 20,
                        backgroundColor: Colors.blue[800],
                        child: CircleAvatar(
                          maxRadius: 18,
                          backgroundImage:
                              NetworkImage(application['companyLogo'] ?? ''),
                        ),
                      ),
                      title: Text(application['jobTitle'] ?? 'Titre inconnu'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (application['companyName']),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                              'Postuler le: ${_formatDate(application['appliedAt'])}'),
                        ],
                      ),
                      onTap: () => _showBottomSheet(context, application),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showBottomSheet(BuildContext context, DocumentSnapshot application) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Modifier la candidature'),
                  onTap: () {
                    Navigator.pop(context);
                    _modifyApplication(context, application);
                  }),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Supprimer la candidature'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteApplication(context, application);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _modifyApplication(BuildContext context, DocumentSnapshot application) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditApplicationPage(application: application),
      ),
    );
  }

  void _deleteApplication(BuildContext context, DocumentSnapshot application) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text(
              'Êtes-vous sûr de vouloir supprimer cette candidature ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Supprimer'),
              onPressed: () {
                Navigator.of(context).pop();
                FirebaseFirestore.instance
                    .collection('applications')
                    .doc(application.id)
                    .delete()
                    .then((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Candidature supprimée avec succès')),
                  );
                }).catchError((error) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Erreur lors de la suppression: $error')),
                  );
                });
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDate(Timestamp timestamp) {
    return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'reviewed':
        return 'Examiné';
      case 'accepted':
        return 'Accepté';
      case 'rejected':
        return 'Refusé';
      default:
        return 'Inconnu';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.transparent;
      case 'reviewed':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
