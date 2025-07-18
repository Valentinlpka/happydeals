import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class Reward {
  final String description;
  final double value;
  final int winnersCount;

  Reward({
    required this.description,
    required this.value,
    required this.winnersCount,
  });

  factory Reward.fromMap(Map<String, dynamic> data) {
    return Reward(
      description: data['description'] ?? '',
      value: (data['value'] ?? 0).toDouble(),
      winnersCount: data['winnersCount'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'value': value,
      'winnersCount': winnersCount,
    };
  }
}

class ContestConditions {
  final bool limitOnePerPerson;
  final int minimumAge;
  final bool requirePurchase;
  final double? minimumPurchaseAmount;
  final String? otherConditions;
  final String? rulesUrl;

  ContestConditions({
    required this.limitOnePerPerson,
    required this.minimumAge,
    this.requirePurchase = false,
    this.minimumPurchaseAmount,
    this.otherConditions,
    this.rulesUrl,
  });

  factory ContestConditions.fromMap(Map<String, dynamic> data) {
    return ContestConditions(
      limitOnePerPerson: data['limitOnePerPerson'] ?? true,
      minimumAge: data['minimumAge'] ?? 18,
      requirePurchase: data['requirePurchase'] ?? false,
      minimumPurchaseAmount: data['minimumPurchaseAmount']?.toDouble(),
      otherConditions: data['otherConditions'],
      rulesUrl: data['rulesUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'limitOnePerPerson': limitOnePerPerson,
      'minimumAge': minimumAge,
      'requirePurchase': requirePurchase,
      'minimumPurchaseAmount': minimumPurchaseAmount,
      'otherConditions': otherConditions,
      'rulesUrl': rulesUrl,
    };
  }
}

class Participant {
  final String userId;
  final DateTime participationDate;
  final Map<String, dynamic>? answers;

  Participant({
    required this.userId,
    required this.participationDate,
    this.answers,
  });

  factory Participant.fromMap(Map<String, dynamic> data) {
    return Participant(
      userId: data['userId'],
      participationDate: (data['participationDate'] as Timestamp).toDate(),
      answers: data['answers'],
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'participationDate': Timestamp.fromDate(participationDate),
        'answers': answers,
      };
}

class Contest extends Post {
  final String title;
  final String searchText;
  final String description;
  final List<Reward> rewards;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime drawDate;
  final DateTime announcementDate;
  final String announcementMethod;
  final ContestConditions conditions;
  final String image;
  final List<String> keywords;
  final String? additionalInfo;
  final int participantsCount;
  final bool isActive;
  final List<Participant>? participants;
  final Map<String, dynamic>? winner;
  final Map<String, dynamic>? companyAddress;

  Contest({
    required super.id,
    required super.timestamp,
    required String authorId,
    required this.title,
    required this.searchText,
    required this.description,
    required this.rewards,
    required super.companyId,
    required this.startDate,
    required this.endDate,
    required this.drawDate,
    required this.announcementDate,
    required this.announcementMethod,
    required this.conditions,
    required this.image,
    required this.keywords,
    this.additionalInfo,
    required this.participantsCount,
    required this.isActive,
    this.participants,
    this.winner,
    this.companyAddress,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
    required super.companyName,
    required super.companyLogo,
  }) : super(type: 'contest');

  factory Contest.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contest(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorId: data['authorId'] ?? 'Auteur inconnu',
      title: data['title'] ?? 'Titre inconnu',
      searchText: data['searchText'] ?? '',
      description: data['description'] ?? '',
      rewards: (data['rewards'] as List<dynamic>?)
              ?.map((rewardData) =>
                  Reward.fromMap(rewardData as Map<String, dynamic>))
              .toList() ??
          [],
      companyId: data['companyId'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      drawDate: (data['drawDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      announcementDate: (data['announcementDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      announcementMethod: data['announcementMethod'] ?? '',
      conditions: ContestConditions.fromMap(data['conditions'] ?? {}),
      image: data['image'] ?? '',
      keywords: List<String>.from(data['keywords'] ?? []),
      additionalInfo: data['additionalInfo'],
      participantsCount: data['participantsCount'] ?? 0,
      isActive: data['isActive'] ?? false,
      participants: (data['participants'] as List<dynamic>?)
              ?.map((participantData) =>
                  Participant.fromMap(participantData as Map<String, dynamic>))
              .toList() ??
          [],
      winner: data['winner'],
      companyAddress: data['companyAddress'] as Map<String, dynamic>?,
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      companyName: data['companyName'] ?? '',
      companyLogo: data['companyLogo'] ?? '',
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
      'description': description,
      'rewards': rewards.map((reward) => reward.toMap()).toList(),
      'companyId': companyId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'drawDate': Timestamp.fromDate(drawDate),
      'announcementDate': Timestamp.fromDate(announcementDate),
      'announcementMethod': announcementMethod,
      'conditions': conditions.toMap(),
      'image': image,
      'keywords': keywords,
      'additionalInfo': additionalInfo,
      'participantsCount': participantsCount,
      'isActive': isActive,
      'winner': winner,
      'companyAddress': companyAddress,
    });
    return map;
  }
}
