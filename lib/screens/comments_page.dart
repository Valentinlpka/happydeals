import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class CommentScreen extends StatefulWidget {
  final Post post;
  final String currentUserId;

  CommentScreen({
    required this.post,
    required this.currentUserId,
  });

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController _commentController = TextEditingController();

  Future<void> _addComment() async {
    String content = _commentController.text;
    if (content.isEmpty) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .get();
    Map<String, dynamic> userInfo = userDoc.data() as Map<String, dynamic>;

    Comment comment = Comment(
      userId: widget.currentUserId,
      content: content,
      timestamp: Timestamp.now(),
      username: userInfo['username'],
      imageProfile: userInfo['image_profile'],
    );

    FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
      'comments': FieldValue.arrayUnion([comment.toMap()]),
      'commentsCount': widget.post.commentsCount + 1,
    });

    setState(() {
      widget.post.comments.add(comment);
      widget.post.commentsCount++;
    });

    _commentController.clear();
  }

  Future<void> _deleteComment(Comment comment) async {
    FirebaseFirestore.instance.collection('posts').doc(widget.post.id).update({
      'comments': FieldValue.arrayRemove([comment.toMap()]),
      'commentsCount': widget.post.commentsCount - 1,
    });

    setState(() {
      widget.post.comments.remove(comment);
      widget.post.commentsCount--;
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

    setState(() {
      int commentIndex = widget.post.comments.indexWhere((c) =>
          c.userId == oldComment.userId && c.content == oldComment.content);
      if (commentIndex != -1) {
        widget.post.comments[commentIndex] = Comment(
            userId: oldComment.userId,
            content: newContent,
            timestamp: oldComment.timestamp,
            username: oldComment.username,
            imageProfile: oldComment.imageProfile);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Commentaires'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.post.comments.length,
              itemBuilder: (context, index) {
                Comment comment = widget.post.comments[index];
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
                          backgroundImage: NetworkImage(comment.imageProfile),
                        ),
                      ),
                      title: Text(comment.username,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          )),
                      subtitle: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(comment.content,
                              style: TextStyle(
                                fontSize: 16,
                              )),
                          Text(
                              _timeAgo(
                                comment.timestamp,
                              ),
                              style: TextStyle(
                                fontSize: 12,
                              )),
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
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Modifier'),
                                ),
                                PopupMenuItem(
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: SafeArea(
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
                    icon: Icon(Icons.send),
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
          title: Text('Modifier le commentaire'),
          content: TextField(
            controller: editController,
            decoration: InputDecoration(
              hintText: 'Modifier votre commentaire',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler',
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
              child: Text('Enregistrer',
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
