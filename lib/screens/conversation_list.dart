import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:provider/provider.dart';

class ConversationsListScreen extends StatelessWidget {
  final String userId;

  const ConversationsListScreen({super.key, required this.userId});

  String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a $weeks sem';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a $months mois';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'Il y a $years an${years > 1 ? 's' : ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationService = Provider.of<ConversationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes conversations'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: conversationService.getUserConversations(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune conversation trouvée'));
          }

          // Créer un Map pour stocker les conversations uniques
          final Map<String, Conversation> uniqueConversations = {};
          for (var conversation in snapshot.data!) {
            String key = conversation.particulierId == userId
                ? conversation.entrepriseId
                : conversation.particulierId;
            if (!uniqueConversations.containsKey(key) ||
                conversation.lastMessageTimestamp
                    .isAfter(uniqueConversations[key]!.lastMessageTimestamp)) {
              uniqueConversations[key] = conversation;
            }
          }

          return ListView.builder(
            itemCount: uniqueConversations.length,
            itemBuilder: (context, index) {
              final conversation = uniqueConversations.values.elementAt(index);
              final otherUserId = conversation.entrepriseId == userId
                  ? conversation.particulierId
                  : conversation.entrepriseId;
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('companys')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(child: CircularProgressIndicator()),
                      title: Text('Chargement...'),
                    );
                  }

                  if (userSnapshot.hasError || !userSnapshot.hasData) {
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.error)),
                      title: Text('Erreur: ${userSnapshot.error}'),
                    );
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final String companyName =
                      capitalizeFirstLetter(userData['name']);
                  final String profilePicUrl = userData['logo'];

                  return Card(
                    elevation: 1,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: profilePicUrl.isNotEmpty
                            ? NetworkImage(profilePicUrl)
                            : null,
                        child: profilePicUrl.isEmpty
                            ? Text(companyName.isNotEmpty ? companyName[0] : '')
                            : null,
                      ),
                      title: Text(companyName),
                      subtitle: Text(conversation.lastMessage),
                      trailing: Text(formatRelativeTime(
                          conversation.lastMessageTimestamp)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ConversationDetailScreen(
                              conversationId: conversation.id,
                              otherUserName: companyName,
                            ),
                          ),
                        );
                      },
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
