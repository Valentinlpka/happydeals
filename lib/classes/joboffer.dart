import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class JobOffer extends Post {
  final String title;
  final String searchText;
  final String city;
  final String description;
  final String missions;
  final String profile;
  final String benefits;
  final String whyJoin;
  final List<String> keywords;
  final String? contractType;
  final String? workingHours;
  final String? salary;
  final String industrySector;

  static const List<String> industrySectors = [
    'Services à domicile',
    'Bricolage et travaux',
    'Garde d\'enfants',
    'Cours particuliers',
    'Jardinage',
    'Informatique et multimédia',
    'Beauté et bien-être',
    'Sport et fitness',
    'Événementiel et animation',
    'Musique et arts',
    'Cuisine et pâtisserie',
    'Photographie et vidéo',
    'Traduction et rédaction',
    'Conseil et coaching',
    'Réparation automobile',
    'Déménagement et manutention',
    'Couture et retouches',
    'Services aux animaux',
    'Soutien scolaire',
    'Autres services',
  ];

  JobOffer({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.searchText,
    required this.city,
    required this.description,
    required this.missions,
    required this.profile,
    required this.industrySector,
    required this.benefits,
    required this.whyJoin,
    required this.keywords,
    required super.companyId,
    this.contractType,
    this.workingHours,
    this.salary,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
  }) : super(
          type: 'job_offer',
        );

  factory JobOffer.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobOffer(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      title: data['title'] ?? '',
      searchText: data['searchText'] ?? '',
      city: data['city'] ?? '',
      description: data['description'] ?? '',
      missions: data['missions'] ?? '',
      profile: data['profile'] ?? '',
      salary: data['salary'],
      contractType: data['contractType'],
      workingHours: data['workingHours'],
      benefits: data['benefits'] ?? '',
      whyJoin: data['why_join'] ?? '',
      keywords: _safeList(data['keywords']),
      companyId: data['companyId'] ?? '',
      industrySector: data['industrySector'] ?? '',
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: _safeList(data['likedBy']),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
    );
  }

  static List<String> _safeList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'searchText': searchText,
      'city': city,
      'description': description,
      'missions': missions,
      'profile': profile,
      'benefits': benefits,
      'why_join': whyJoin,
      'keywords': keywords,
      'companyId': companyId,
      'contractType': contractType,
      'workingHours': workingHours,
      'salary': salary,
      'industrySector': industrySector,
    });
    return map;
  }
}
