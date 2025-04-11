// Créez un nouveau fichier screens/single_chat_search.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/conversation_detail.dart';

class SingleChatSearchScreen extends StatefulWidget {
  const SingleChatSearchScreen({super.key});

  @override
  State<SingleChatSearchScreen> createState() => _SingleChatSearchScreenState();
}

class _SingleChatSearchScreenState extends State<SingleChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Stream<QuerySnapshot>? _searchResults;
  Timer? _debounce;
  List<String> _followedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadFollowedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFollowedUsers() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    if (userDoc.exists) {
      setState(() {
        _followedUsers =
            List<String>.from(userDoc.data()?['followedUsers'] ?? []);
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty || _followedUsers.isEmpty) {
        setState(() {
          _searchResults = null;
        });
        return;
      }

      setState(() {
        _searchResults = FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: _followedUsers)
            .where('searchName', arrayContains: query.toLowerCase())
            .limit(20)
            .snapshots();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Rechercher une personne...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.shade400),
          ),
          style: const TextStyle(fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _searchResults,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Recherchez une personne\npour démarrer une conversation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final users = snapshot.data!.docs;

          if (!snapshot.hasData && _searchController.text.isEmpty) {
            return _buildEmptySearchState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data() as Map<String, dynamic>;
              return _UserListItem(
                user: user,
                userId: users[index].id,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_add,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          if (_followedUsers.isEmpty)
            Text(
              'Vous ne suivez aucun utilisateur\nCommencez par suivre des personnes',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            )
          else
            Text(
              'Recherchez parmi vos contacts\npour créer un groupe',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final String userId;

  const _UserListItem({
    required this.user,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: user['image_profile'] != null
            ? NetworkImage(user['image_profile'])
            : null,
        child: user['image_profile'] == null
            ? Text(
                '${user['firstName']?[0] ?? ''}${user['lastName']?[0] ?? ''}',
                style: const TextStyle(fontSize: 16),
              )
            : null,
      ),
      title: Text(
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      onTap: () async {
        // Vérifier d'abord si une conversation existe déjà
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId == null) return;

        final conversationQuery = await FirebaseFirestore.instance
            .collection('conversations')
            .where('adId', isEqualTo: null)
            .where('isGroup', isEqualTo: false)
            .get();

        for (var doc in conversationQuery.docs) {
          final data = doc.data();
          final bool isMatch = ((data['particulierId'] == userId &&
                  data['otherUserId'] == currentUserId) ||
              (data['particulierId'] == currentUserId &&
                  data['otherUserId'] == userId));

          String? existingConversationId;
          if (isMatch) {
            existingConversationId = doc.id;
            debugPrint('Ca marche on a trouvé une conversation');
          }

          if (!context.mounted) return;
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationDetailScreen(
                conversationId: existingConversationId ??
                    '', // Conversation existante ou vide
                otherUserName: '${user['firstName']} ${user['lastName']}',
                otherUserId: userId,
                isNewConversation: existingConversationId ==
                    null, // Nouveau seulement si pas d'existant
              ),
            ),
          );
        }
      },
    );
  }
}
