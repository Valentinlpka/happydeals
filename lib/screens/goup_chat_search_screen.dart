// Modifions le code pour supporter la recherche mixte
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

class GroupChatSearchScreen extends StatefulWidget {
  final Company? preselectedCompany;

  const GroupChatSearchScreen({
    super.key,
    this.preselectedCompany,
  });

  @override
  State<GroupChatSearchScreen> createState() => _GroupChatSearchScreenState();
}

class _GroupChatSearchScreenState extends State<GroupChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  Stream<List<QuerySnapshot>>? _searchResults;
  Timer? _debounce;
  final Set<String> _selectedMembers = {};
  final Map<String, Map<String, dynamic>> _selectedMembersData = {};
  final Map<String, String> _memberTypes = {}; // 'company' ou 'user'
  List<String> _followedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadFollowedUsers();
    if (widget.preselectedCompany != null) {
      _selectedMembers.add(widget.preselectedCompany!.id);
      _selectedMembersData[widget.preselectedCompany!.id] = {
        'name': widget.preselectedCompany!.name,
        'logo': widget.preselectedCompany!.logo,
      };
      _memberTypes[widget.preselectedCompany!.id] = 'company';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

// Dans _GroupChatSearchScreenState

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
      if (query.isEmpty) {
        setState(() {
          _searchResults = null;
        });
        return;
      }

      try {
        final companiesStream = FirebaseFirestore.instance
            .collection('companys')
            .where('searchName', arrayContains: query.toLowerCase())
            .limit(10)
            .snapshots()
            .handleError((error) {});

        final usersStream = _followedUsers.isEmpty
            ? FirebaseFirestore.instance
                .collection('users')
                .where('id', isEqualTo: 'non_existent_id')
                .snapshots()
            : FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: _followedUsers)
                .where('searchName', arrayContains: query.toLowerCase())
                .limit(10)
                .snapshots()
                .handleError((error) {});

        setState(() {
          _searchResults = Rx.combineLatest2(
            companiesStream,
            usersStream,
            (QuerySnapshot companies, QuerySnapshot users) =>
                [companies, users],
          );
        });
      } catch (e) {}
    });
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

  void _toggleMemberSelection(
      String id, Map<String, dynamic> data, String type) {
    if (widget.preselectedCompany?.id == id)
      return; // Ne rien faire si c'est l'entreprise présélectionnée
    setState(() {
      if (_selectedMembers.contains(id)) {
        _selectedMembers.remove(id);
        _selectedMembersData.remove(id);
        _memberTypes.remove(id);
      } else {
        _selectedMembers.add(id);
        _selectedMembersData[id] = data;
        _memberTypes[id] = type;
      }
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
            hintText: 'Rechercher entreprises ou particuliers...',
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
      body: Column(
        children: [
          if (_selectedMembers.isNotEmpty) _buildSelectedMembers(),
          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: _searchResults,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (!snapshot.hasData && _searchController.text.isEmpty) {
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
                        Text(
                          'Recherchez des membres\npour créer un groupe',
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

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final companies = snapshot.data![0].docs;
                final users = snapshot.data![1].docs;

                if (!snapshot.hasData && _searchController.text.isEmpty) {
                  return _buildEmptySearchState();
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (companies.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Text(
                          'Entreprises',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ...companies.map((doc) {
                        final company = doc.data() as Map<String, dynamic>;
                        return _MemberListItem(
                          data: company,
                          id: doc.id,
                          type: 'company',
                          isSelected: _selectedMembers.contains(doc.id),
                          onTap: () => _toggleMemberSelection(
                            doc.id,
                            company,
                            'company',
                          ),
                        );
                      }),
                    ],
                    if (users.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            20, companies.isEmpty ? 8 : 20, 20, 12),
                        child: const Text(
                          'Particuliers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      ...users.map((doc) {
                        final user = doc.data() as Map<String, dynamic>;
                        return _MemberListItem(
                          data: user,
                          id: doc.id,
                          type: 'user',
                          isSelected: _selectedMembers.contains(doc.id),
                          onTap: () => _toggleMemberSelection(
                            doc.id,
                            user,
                            'user',
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          _selectedMembers.isNotEmpty ? _buildCreateGroupButton() : null,
    );
  }

  Widget _buildSelectedMembers() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _groupNameController,
            decoration: const InputDecoration(
              hintText: 'Nom du groupe',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Membres sélectionnés',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedMembers.length,
              itemBuilder: (context, index) {
                final id = _selectedMembers.elementAt(index);
                final data = _selectedMembersData[id]!;
                final type = _memberTypes[id]!;
                final isPreselected = widget.preselectedCompany?.id == id;

                String name;
                String? imageUrl;

                if (type == 'company') {
                  name = data['name'];
                  imageUrl = data['logo'];
                } else {
                  name = '${data['firstName']} ${data['lastName']}';
                  imageUrl = data['image_profile'];
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundImage:
                          imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null ? Text(name[0]) : null,
                    ),
                    label: Text(name),
                    deleteIcon: isPreselected
                        ? null
                        : const Icon(Icons.close, size: 18),
                    onDeleted: isPreselected
                        ? null
                        : () => _toggleMemberSelection(id, data, type),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateGroupButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _createGroup,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Créer le groupe (${_selectedMembers.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    if (_selectedMembers.isEmpty || _groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Veuillez sélectionner au moins un membre et donner un nom au groupe'),
        ),
      );
      return;
    }

    final conversationService =
        Provider.of<ConversationService>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    try {
      // Créer une map des membres avec leur type
      final members = _selectedMembers.map((id) {
        return {
          'id': id,
          'type': _memberTypes[id],
          'name': _memberTypes[id] == 'company'
              ? _selectedMembersData[id]!['name']
              : '${_selectedMembersData[id]!['firstName']} ${_selectedMembersData[id]!['lastName']}',
        };
      }).toList();

      final conversationId = await conversationService.createGroupConversation(
        currentUserId,
        members,
        _groupNameController.text.trim(),
      );

      if (!context.mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            conversationId: conversationId,
            otherUserName: _groupNameController.text.trim(),
            isGroup: true,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  // ... Le reste du code reste le même (buildCreateGroupButton, etc.)
}

class _MemberListItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String id;
  final String type;
  final bool isSelected;
  final VoidCallback onTap;

  const _MemberListItem({
    required this.data,
    required this.id,
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String name;
    final String? imageUrl;

    if (type == 'company') {
      name = data['name'];
      imageUrl = data['logo'];
    } else {
      name = '${data['firstName']} ${data['lastName']}';
      imageUrl = data['image_profile'];
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
            child: imageUrl == null
                ? Text(
                    name[0],
                    style: const TextStyle(fontSize: 16),
                  )
                : null,
          ),
          if (isSelected)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: type == 'company' ? const Text('Entreprise') : null,
      onTap: onTap,
    );
  }
}
