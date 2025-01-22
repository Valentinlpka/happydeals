import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/application_details_page.dart';
import 'package:happy/screens/post_type_page/job_search_profile_page.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:intl/intl.dart';

class UserApplicationsPage extends StatelessWidget {
  const UserApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    print('Current user ID: ${user?.uid}');

    return Scaffold(
      appBar: const CustomAppBarBack(
        title: 'Mes candidatures',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[800]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JobSearchProfilePage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Gérer mon espace candidature',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('applications')
                  .where('applicantId', isEqualTo: user?.uid)
                  .orderBy('lastUpdate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                print('Connection State: ${snapshot.connectionState}');
                print('Has Error: ${snapshot.hasError}');
                if (snapshot.hasError) {
                  print('Error: ${snapshot.error}');
                }
                print('Has Data: ${snapshot.hasData}');
                if (snapshot.hasData) {
                  print('Number of docs: ${snapshot.data?.docs.length}');
                  snapshot.data?.docs.forEach((doc) {
                    print('Application ID: ${doc.id}');
                    print('Application Data: ${doc.data()}');
                  });
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_off_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune candidature trouvée',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var application = snapshot.data!.docs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[700],
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(
                              application['companyLogo'] ?? '',
                            ),
                          ),
                        ),
                        title: Text(
                          application['jobTitle'] ?? 'Titre inconnu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(application['companyName'] ?? ''),
                            const SizedBox(height: 4),
                            Text(
                              'Postuler le: ${_formatDate(application['appliedAt'])}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildStatusChip(application['status']),
                          ],
                        ),
                        trailing: application['hasUnreadMessages'] == true
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  '!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => _navigateToApplicationDetails(
                          context,
                          application,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (status) {
      case 'Envoyé':
        backgroundColor = Colors.blue;
        break;
      case 'Nouveau Message':
        backgroundColor = Colors.orange;
        break;
      case 'Accepté':
        backgroundColor = Colors.green;
        break;
      case 'Refusé':
        backgroundColor = Colors.red;
        break;
      case 'Demande d\'infos':
        backgroundColor = Colors.purple;
        break;
      default:
        backgroundColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _navigateToApplicationDetails(
    BuildContext context,
    DocumentSnapshot application,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplicationDetailsPage(
          application: application,
        ),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  }
}
