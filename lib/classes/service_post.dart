import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/classes/service_discount.dart';

class ServicePost extends Post {
  final String serviceId;
  final String name;
  final String description;
  final double price;
  final double priceHT;
  final int tva;
  final int duration;
  final List<String> images;
  final bool isActive;
  final ServiceDiscount? discount;
  final String professionalId;

  ServicePost({
    required super.id,
    required super.companyId,
    required super.timestamp,
    required this.serviceId,
    required this.name,
    required this.description,
    required this.price,
    required this.priceHT,
    required this.tva,
    required this.duration,
    required this.images,
    required this.professionalId,
    this.isActive = true,
    this.discount,
    super.views = 0,
    super.likes = 0,
    super.likedBy = const [],
    super.commentsCount = 0,
    super.comments = const [],
  })  : assert(serviceId.isNotEmpty, 'serviceId ne peut pas être vide'),
        super(type: 'service');

  factory ServicePost.fromService(ServiceModel service) {
    if (service.id.isEmpty) {
      throw Exception('Service ID cannot be empty');
    }

    print('Creating ServicePost from service: ${service.id}');
    final post = ServicePost(
      id: FirebaseFirestore.instance.collection('posts').doc().id,
      companyId: service.professionalId,
      timestamp: DateTime.now(),
      serviceId: FirebaseFirestore.instance.collection('posts').doc().id,
      name: service.name,
      description: service.description,
      price: service.price,
      priceHT: service.price / (1 + service.tva / 100),
      tva: service.tva.toInt(),
      duration: service.duration,
      images: service.images,
      professionalId: service.professionalId,
      isActive: service.isActive,
      discount: service.discount != null
          ? ServiceDiscount.fromMap(service.discount!)
          : null,
    );
    print('Created ServicePost: ${post.toMap()}');
    return post;
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'serviceId': serviceId,
      'name': name,
      'description': description,
      'price': price,
      'priceHT': priceHT,
      'tva': tva,
      'duration': duration,
      'images': images,
      'isActive': isActive,
      'professionalId': professionalId,
      'discount': discount != null
          ? {
              'type': discount!.type,
              'value': discount!.value,
              'startDate': Timestamp.fromDate(discount!.startDate),
              'endDate': Timestamp.fromDate(discount!.endDate),
              'isActive': discount!.isActive,
            }
          : null,
    });
    return map;
  }

  factory ServicePost.fromDocument(DocumentSnapshot doc) {
    print('Creating ServicePost from document: ${doc.id}');
    final data = doc.data() as Map<String, dynamic>;

    final serviceId = data['id'] ?? '';
    if (serviceId.isEmpty) {
      print('ATTENTION: serviceId est vide pour le post ${doc.id}');
    }

    final post = ServicePost(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      serviceId: serviceId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      priceHT: (data['priceHT'] ?? 0.0).toDouble(),
      tva: data['tva'] ?? 20,
      duration: data['duration'] ?? 30,
      images: List<String>.from(data['images'] ?? []),
      professionalId: data['professionalId'] ?? '',
      isActive: data['isActive'] ?? true,
      discount: data['discount'] != null
          ? ServiceDiscount.fromMap(data['discount'])
          : null,
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
    );
    print('Created ServicePost from document: ${post.toMap()}');
    return post;
  }
}
