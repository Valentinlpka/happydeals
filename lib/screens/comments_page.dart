import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';

class CommentScreen extends StatefulWidget {
  final Post post;
  final String currentUserId;

  const CommentScreen({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController _commentController = TextEditingController();

  Future<void> _addComment() async {
    String content = _commentController.text;
    if (content.isEmpty) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      Map<String, dynamic> userInfo = userDoc.data() as Map<String, dynamic>;

      // Créer le nom d'utilisateur à partir de firstName et lastName
      String username =
          '${userInfo['firstName'] ?? ''} ${userInfo['lastName'] ?? ''}'.trim();

      Comment comment = Comment(
        userId: widget.currentUserId,
        content: content,
        timestamp: Timestamp.now(),
        username: username, // Utiliser le nom créé
        imageProfile:
            userInfo['image_profile'] ?? '', // Ajouter une valeur par défaut
      );

      // Utiliser une transaction pour la cohérence des données
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postRef =
            FirebaseFirestore.instance.collection('posts').doc(widget.post.id);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        transaction.update(postRef, {
          'comments': FieldValue.arrayUnion([comment.toMap()]),
          'commentsCount': FieldValue.increment(1),
        });
      });

      _commentController.clear();
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout du commentaire: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erreur lors de l\'ajout du commentaire')),
        );
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
      'comments': FieldValue.arrayRemove([comment.toMap()]),
      'commentsCount': widget.post.commentsCount - 1,
    });
  }

  Future<void> _editComment(Comment oldComment, String newContent) async {
    final postRef =
        FirebaseFirestore.instance.collection('posts').doc(widget.post.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) {
        throw Exception("Post does not exist!");
      }

      final List<dynamic> comments = List.from(postSnapshot['comments']);
      final int commentIndex = comments.indexWhere((c) =>
          c['userId'] == oldComment.userId &&
          c['content'] == oldComment.content);

      if (commentIndex != -1) {
        comments[commentIndex]['content'] = newContent;
        transaction.update(postRef, {'comments': comments});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commentaires'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final postData = snapshot.data!.data() as Map<String, dynamic>;
                final comments = (postData['comments'] as List?)
                        ?.map((commentData) => Comment(
                              userId: commentData['userId'],
                              content: commentData['content'],
                              timestamp: commentData['timestamp'],
                              username: commentData['username'],
                              imageProfile: commentData['imageProfile'],
                            ))
                        .toList() ??
                    [];

                if (comments.isEmpty) {
                  return const Center(
                    child: Text('Aucun commentaire pour le moment'),
                  );
                }

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    Comment comment = comments[index];
                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            minRadius: 10,
                            maxRadius: 27,
                            backgroundColor: Colors.blue,
                            child: CircleAvatar(
                              minRadius: 20,
                              maxRadius: 25,
                              backgroundImage:
                                  NetworkImage(comment.imageProfile),
                            ),
                          ),
                          title: Text(
                            comment.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                comment.content,
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                _timeAgo(comment.timestamp),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: widget.currentUserId == comment.userId
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editCommentDialog(comment);
                                    } else if (value == 'delete') {
                                      _deleteComment(comment);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Modifier'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Supprimer'),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        Divider(color: Colors.grey[300]),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Veuillez écrire votre commentaire',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _addComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editCommentDialog(Comment comment) {
    TextEditingController editController =
        TextEditingController(text: comment.content);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier le commentaire'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(
              hintText: 'Modifier votre commentaire',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler',
                  style: TextStyle(
                    color: Colors.red,
                  )),
            ),
            TextButton(
              onPressed: () {
                _editComment(comment, editController.text).then((_) {
                  setState(() {});
                });
                Navigator.of(context).pop();
              },
              child: const Text('Enregistrer',
                  style: TextStyle(
                    color: Colors.green,
                  )),
            ),
          ],
        );
      },
    );
  }

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 1) {
      return 'il y a ${difference.inDays} jours';
    } else if (difference.inHours > 1) {
      return 'il y a ${difference.inHours} heures';
    } else if (difference.inMinutes > 1) {
      return 'il y a ${difference.inMinutes} minutes';
    } else {
      return 'à l\'instant';
    }
  }
}
