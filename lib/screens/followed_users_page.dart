import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class FollowedUsersPage extends StatelessWidget {
  const FollowedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Personnes suivies',
        align: Alignment.center,
      ),
      body: Consumer<UserModel>(
        builder: (context, userModel, _) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: userModel.followedUsers)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Une erreur est survenue: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('Vous ne suivez personne pour le moment'),
                );
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final userData =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final isFollowingBack =
                      (userData['followedUsers'] as List<dynamic>?)
                              ?.contains(userModel.userId) ??
                          false;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                Profile(userId: snapshot.data!.docs[index].id)),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage:
                                  userData['image_profile'] != null &&
                                          userData['image_profile']
                                              .toString()
                                              .isNotEmpty
                                      ? NetworkImage(userData['image_profile'])
                                      : null,
                              child: userData['image_profile'] == null ||
                                      userData['image_profile']
                                          .toString()
                                          .isEmpty
                                  ? const Icon(Icons.person, size: 30)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${userData['firstName']} ${userData['lastName']}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isFollowingBack &&
                                      userData['uniqueCode'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code unique: ${userData['uniqueCode']}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_remove),
                              onPressed: () {
                                userModel.unfollowUser(
                                    snapshot.data!.docs[index].id);
                              },
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
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
}
