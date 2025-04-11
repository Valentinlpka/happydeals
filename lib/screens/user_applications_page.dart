import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/application_details_page.dart';
import 'package:happy/screens/post_type_page/job_search_profile_page.dart';
import 'package:happy/widgets/app_bar/custom_app_bar_back.dart';
import 'package:intl/intl.dart';

class UserApplicationsPage extends StatelessWidget {
  const UserApplicationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('Current user ID: ${user?.uid}');

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
                    color: Colors.blue.withAlpha(26 * 3),
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
                      color: Colors.white.withAlpha(26 * 9),
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
                debugPrint('Connection State: ${snapshot.connectionState}');
                debugPrint('Has Error: ${snapshot.hasError}');
                if (snapshot.hasError) {
                  debugPrint('Error: ${snapshot.error}');
                }
                debugPrint('Has Data: ${snapshot.hasData}');
                if (snapshot.hasData) {
                  debugPrint('Number of docs: ${snapshot.data?.docs.length}');
                  snapshot.data?.docs.forEach((doc) {
                    debugPrint('Application ID: ${doc.id}');
                    debugPrint('Application Data: ${doc.data()}');
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
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withAlpha(26 * 2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _navigateToApplicationDetails(
                              context, application),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            application['jobTitle'] ??
                                                'Titre inconnu',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Postuler le: ${_formatDate(application['appliedAt'])}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildStatusChip(
                                        application['status'],
                                        application.data()
                                            as Map<String, dynamic>),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                Colors.blue.withAlpha(26 * 2),
                                            width: 2,
                                          ),
                                          image: DecorationImage(
                                            image: NetworkImage(
                                              application['companyLogo'] ?? '',
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              application['companyName'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if ((application.data()
                                                        as Map<String, dynamic>)
                                                    .containsKey(
                                                        'userUnreadMessages') &&
                                                application[
                                                        'userUnreadMessages'] ==
                                                    true) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[50],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.mail_outline,
                                                      size: 14,
                                                      color: Colors.red[700],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Nouveau message',
                                                      style: TextStyle(
                                                        color: Colors.red[700],
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                        color: Colors.grey[400],
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Map<String, dynamic> application) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'Envoyé':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        text = 'Envoyé';
        icon = Icons.send_outlined;
        break;
      case 'Accepté':
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        text = 'Accepté';
        icon = Icons.check_circle_outline;
        break;
      case 'Refusé':
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        text = 'Refusé';
        icon = Icons.cancel_outlined;
        break;
      case 'Demande d\'infos':
        backgroundColor = Colors.purple[50]!;
        textColor = Colors.purple[700]!;
        text = 'Demande d\'infos';
        icon = Icons.info_outline;
        break;
      case 'En cours':
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        text = "En cours";
        icon = Icons.delete_outline_outlined;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        text = status;
        icon = Icons.help_outline;
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
