import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class Event extends Post {
  final String title;
  final String searchText;

  final String category;
  final DateTime eventDate;
  final String city;
  final String description;
  final List<String> products;
  final String photo;

  Event({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.searchText,
    required this.category,
    required this.eventDate,
    required this.city,
    required this.description,
    required super.companyId,
    required this.products,
    required this.photo,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
  }) : super(
          type: 'event',
        );

  factory Event.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      title: data['title'],
      searchText: data['searchText'],
      category: data['category'],
      eventDate: (data['eventDate'] as Timestamp).toDate(),
      city: data['city'],
      description: data['description'],
      companyId: data['companyId'],
      products: List<String>.from(data['products']),
      photo: data['photo'],
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'searchText': searchText,
      'category': category,
      'eventDate': Timestamp.fromDate(eventDate),
      'city': city,
      'description': description,
      'products': products,
      'photo': photo,
      'companyId': companyId,
    });
    return map;
  }
}
