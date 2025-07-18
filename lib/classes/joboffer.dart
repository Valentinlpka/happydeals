import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class JobOffer extends Post {
  final String title;
  final String searchText;
  final String city;
  final String description;
  final String missions;
  final String profile;
  final List<String> benefits;
  final String whyJoin;
  final List<String> keywords;
  final String? contractType;
  final String? workingHours;
  final String? salary;
  final String industrySector;
  final String workplaceType;
  final Map<String, dynamic>? companyAddress;
  final String status;
  @override
  final List<String> viewedBy;
  final String address;
  final String additionalInfo;
  final String startDate;
  final String applicationDeadline;
  final int numberOfPositions;
  final String experienceRequired;
  final String educationRequired;
  final List<String> requiredLicenses;
  final String workingRhythm;
  final bool weekendWork;
  final String weekendWorkDetails;
  final String salaryMin;
  final String salaryMax;
  final String variableCompensation;

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
    required this.workplaceType,
    required this.keywords,
    required super.companyId,
    this.contractType,
    this.workingHours,
    this.salary,
    required super.companyName,
    required super.companyLogo,
    this.companyAddress,
    this.status = 'active',
    this.viewedBy = const [],
    this.address = '',
    this.additionalInfo = '',
    this.startDate = '',
    this.applicationDeadline = '',
    this.numberOfPositions = 1,
    this.experienceRequired = '',
    this.educationRequired = '',
    this.requiredLicenses = const [],
    this.workingRhythm = '',
    this.weekendWork = false,
    this.weekendWorkDetails = '',
    this.salaryMin = '',
    this.salaryMax = '',
    this.variableCompensation = '',
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
  }) : super(type: 'job_offer');

  factory JobOffer.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Conversion sécurisée des listes
    List<String> convertToStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      if (value is String) {
        return [value];
      }
      return [];
    }

    return JobOffer(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: data['title']?.toString() ?? '',
      searchText: data['searchText']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      missions: data['missions']?.toString() ?? '',
      profile: data['profile']?.toString() ?? '',
      workplaceType: data['workplaceType']?.toString() ?? '',
      salary: data['salary']?.toString(),
      contractType: data['contractType']?.toString(),
      workingHours: data['workingHours']?.toString(),
      benefits: convertToStringList(data['benefits']),
      whyJoin: data['why_join']?.toString() ?? '',
      keywords: convertToStringList(data['keywords']),
      companyId: data['companyId']?.toString() ?? '',
      industrySector: data['industrySector']?.toString() ?? '',
      views: (data['views'] is num) ? (data['views'] as num).toInt() : 0,
      likes: (data['likes'] is num) ? (data['likes'] as num).toInt() : 0,
      likedBy: convertToStringList(data['likedBy']),
      commentsCount: (data['commentsCount'] is num) ? (data['commentsCount'] as num).toInt() : 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
      companyName: data['companyName']?.toString() ?? '',
      companyLogo: data['companyLogo']?.toString() ?? '',
      companyAddress: data['companyAddress'] as Map<String, dynamic>?,
      status: data['status']?.toString() ?? 'active',
      viewedBy: convertToStringList(data['viewedBy']),
      address: data['address']?.toString() ?? '',
      additionalInfo: data['additionalInfo']?.toString() ?? '',
      startDate: data['startDate']?.toString() ?? '',
      applicationDeadline: data['applicationDeadline']?.toString() ?? '',
      numberOfPositions: data['numberOfPositions'] != null ? 
          (data['numberOfPositions'] is String ? 
              int.tryParse(data['numberOfPositions']) ?? 1 : 
              (data['numberOfPositions'] as num).toInt()) : 1,
      experienceRequired: data['experienceRequired']?.toString() ?? '',
      educationRequired: data['educationRequired']?.toString() ?? '',
      requiredLicenses: convertToStringList(data['requiredLicenses']),
      workingRhythm: data['workingRhythm']?.toString() ?? '',
      weekendWork: data['weekendWork'] as bool? ?? false,
      weekendWorkDetails: data['weekendWorkDetails']?.toString() ?? '',
      salaryMin: data['salaryMin']?.toString() ?? '',
      salaryMax: data['salaryMax']?.toString() ?? '',
      variableCompensation: data['variableCompensation']?.toString() ?? '',
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'searchText': searchText,
      'city': city,
      'description': description,
      'industrySector': industrySector,
      'missions': missions,
      'profile': profile,
      'benefits': benefits,
      'why_join': whyJoin,
      'workplaceType': workplaceType,
      'keywords': keywords,
      'companyId': companyId,
      'contractType': contractType,
      'workingHours': workingHours,
      'salary': salary,
      'companyName': companyName,
      'companyLogo': companyLogo,
      'companyAddress': companyAddress,
      'status': status,
      'viewedBy': viewedBy,
      'address': address,
      'additionalInfo': additionalInfo,
      'startDate': startDate,
      'applicationDeadline': applicationDeadline,
      'numberOfPositions': numberOfPositions,
      'experienceRequired': experienceRequired,
      'educationRequired': educationRequired,
      'requiredLicenses': requiredLicenses,
      'workingRhythm': workingRhythm,
      'weekendWork': weekendWork,
      'weekendWorkDetails': weekendWorkDetails,
      'salaryMin': salaryMin,
      'salaryMax': salaryMax,
      'variableCompensation': variableCompensation,
    });
    return map;
  }
}
