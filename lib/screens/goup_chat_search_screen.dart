// Modifions le code pour supporter la recherche mixte
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

class _GroupChatSearchScreenState extends State<GroupChatSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  Stream<List<QuerySnapshot>>? _searchResults;
  Timer? _debounce;
  final Set<String> _selectedMembers = {};
  final Map<String, Map<String, dynamic>> _selectedMembersData = {};
  final Map<String, String> _memberTypes = {}; // 'company' ou 'user'
  List<String> _followedUsers = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
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
    _animationController.dispose();
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
      } catch (e) {
        debugPrint(e.toString());
      }
    });
  }

  Widget _buildEmptySearchState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_add,
              size: 64.sp,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: 16.h),
            if (_followedUsers.isEmpty)
              Text(
                'Vous ne suivez aucun utilisateur\nCommencez par suivre des personnes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16.sp,
                ),
              )
            else
              Text(
                'Recherchez parmi vos contacts\npour créer un groupe',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleMemberSelection(
      String id, Map<String, dynamic> data, String type) {
    if (widget.preselectedCompany?.id == id) {
      return; // Ne rien faire si c'est l'entreprise présélectionnée
    }
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Container(
          height: 40.h,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Rechercher entreprises ou particuliers...',
              border: InputBorder.none,
              hintStyle:
                  TextStyle(color: Colors.grey.shade400, fontSize: 14.sp),
              prefixIcon:
                  Icon(Icons.search, color: Colors.grey.shade400, size: 20.sp),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
            ),
            style: TextStyle(fontSize: 14.sp),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
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
                  return _buildEmptySearchState();
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final companies = snapshot.data![0].docs;
                final users = snapshot.data![1].docs;

                return ListView(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  children: [
                    if (companies.isNotEmpty) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
                        child: Text(
                          'Entreprises',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
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
                          20.w,
                          companies.isEmpty ? 8.h : 20.h,
                          20.w,
                          12.h,
                        ),
                        child: Text(
                          'Particuliers',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
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
            decoration: InputDecoration(
              hintText: 'Nom du groupe',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              prefixIcon:
                  Icon(Icons.group, color: Colors.grey[400], size: 20.sp),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Membres sélectionnés',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14.sp,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 60.h,
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
                  padding: EdgeInsets.only(right: 8.w),
                  child: Chip(
                    avatar: CircleAvatar(
                      backgroundImage:
                          imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null ? Text(name[0]) : null,
                    ),
                    label: Text(
                      name,
                      style: TextStyle(fontSize: 12.sp),
                    ),
                    deleteIcon:
                        isPreselected ? null : Icon(Icons.close, size: 16.sp),
                    onDeleted: isPreselected
                        ? null
                        : () => _toggleMemberSelection(id, data, type),
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _createGroup,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        child: Text(
          'Créer le groupe (${_selectedMembers.length})',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    if (_selectedMembers.isEmpty || _groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez sélectionner au moins un membre et donner un nom au groupe',
            style: TextStyle(fontSize: 14.sp),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
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

      if (!mounted) return;

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur: ${e.toString()}',
            style: TextStyle(fontSize: 14.sp),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
    }
  }
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24.r,
                    backgroundImage:
                        imageUrl != null ? NetworkImage(imageUrl) : null,
                    child: imageUrl == null
                        ? Text(
                            name[0],
                            style: TextStyle(fontSize: 16.sp),
                          )
                        : null,
                  ),
                  if (isSelected)
                    Positioned(
                      right: -2.w,
                      bottom: -2.h,
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.w,
                          ),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 12.sp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.sp,
                      ),
                    ),
                    if (type == 'company')
                      Text(
                        'Entreprise',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.sp,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
