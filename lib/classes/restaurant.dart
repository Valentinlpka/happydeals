import 'package:cloud_firestore/cloud_firestore.dart';

class BaseEntity {
  final String id;
  final String companyId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final int sortOrder;

  BaseEntity({
    required this.id,
    required this.companyId,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.sortOrder = 0,
  });
}

class RestaurantAddress {
  final String address;
  final String codePostal;
  final String ville;
  final String pays;
  final double latitude;
  final double longitude;

  RestaurantAddress({
    required this.address,
    required this.codePostal,
    required this.ville,
    required this.pays,
    required this.latitude,
    required this.longitude,
  });

  factory RestaurantAddress.fromMap(Map<String, dynamic> map) {
    return RestaurantAddress(
      address: map['address'] ?? '',
      codePostal: map['codePostal'] ?? '',
      ville: map['ville'] ?? '',
      pays: map['pays'] ?? 'France',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'codePostal': codePostal,
      'ville': ville,
      'pays': pays,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class SocialMedia {
  final String? facebook;
  final String? instagram;
  final String? twitter;

  SocialMedia({
    this.facebook,
    this.instagram,
    this.twitter,
  });

  factory SocialMedia.fromMap(Map<String, dynamic> map) {
    return SocialMedia(
      facebook: map['facebook'],
      instagram: map['instagram'],
      twitter: map['twitter'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'facebook': facebook,
      'instagram': instagram,
      'twitter': twitter,
    };
  }
}

class SpecialHours {
  final DateTime date;
  final String hours; // "fermé" ou "11:30-14:30"
  final String reason;

  SpecialHours({
    required this.date,
    required this.hours,
    required this.reason,
  });

  factory SpecialHours.fromMap(Map<String, dynamic> map) {
    return SpecialHours(
      date: (map['date'] as Timestamp).toDate(),
      hours: map['hours'] ?? 'fermé',
      reason: map['reason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'hours': hours,
      'reason': reason,
    };
  }
}

class OpeningHours {
  final Map<String, String> schedule;
  final List<SpecialHours> specialHours;

  OpeningHours({
    required this.schedule,
    this.specialHours = const [],
  });

  factory OpeningHours.fromMap(Map<String, dynamic> map) {
    return OpeningHours(
      schedule: Map<String, String>.from(map['schedule'] ?? {}),
      specialHours: (map['specialHours'] as List<dynamic>? ?? [])
          .map((item) => SpecialHours.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schedule': schedule,
      'specialHours': specialHours.map((h) => h.toMap()).toList(),
    };
  }

  bool isOpenNow() {
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    
    // Vérifier les horaires spéciaux
    for (final special in specialHours) {
      if (special.date.day == now.day &&
          special.date.month == now.month &&
          special.date.year == now.year) {
        return special.hours != "fermé" && _isTimeInRange(now, special.hours);
      }
    }

    // Vérifier les horaires normaux
    final todayHours = schedule[dayName];
    if (todayHours == null || todayHours == "fermé") {
      return false;
    }

    return _isTimeInRange(now, todayHours);
  }

  String _getDayName(int weekday) {
    const days = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday'
    ];
    return days[weekday - 1];
  }

  bool _isTimeInRange(DateTime time, String hoursString) {
    if (hoursString == "fermé") return false;
    
    final ranges = hoursString.split(',');
    final currentTime = time.hour * 60 + time.minute;
    
    for (final range in ranges) {
      final parts = range.trim().split('-');
      if (parts.length == 2) {
        final startParts = parts[0].split(':');
        final endParts = parts[1].split(':');
        
        final startTime = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endTime = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        
        if (currentTime >= startTime && currentTime <= endTime) {
          return true;
        }
      }
    }
    
    return false;
  }
}

class Restaurant extends BaseEntity {
  final String name;
  final String description;
  final String email;
  final String phone;
  final String website;
  final RestaurantAddress address;
  final String logo;
  final String cover;
  final List<String> gallery;
  final OpeningHours openingHours;
  final SocialMedia socialMedia;
  final List<String> tags;
  final double rating;
  final int totalReviews;
  final String category;
  final String subCategory;
  final double deliveryRange;
  final double averageOrderValue;
  final int preparationTime;
  double? distance; // Calculée côté client

  Restaurant({
    required super.id,
    required super.companyId,
    required super.createdAt,
    super.updatedAt,
    super.isActive,
    super.sortOrder,
    required this.name,
    required this.description,
    required this.email,
    required this.phone,
    required this.website,
    required this.address,
    required this.logo,
    required this.cover,
    required this.gallery,
    required this.openingHours,
    required this.socialMedia,
    required this.tags,
    required this.rating,
    required this.totalReviews,
    required this.category,
    required this.subCategory,
    required this.deliveryRange,
    required this.averageOrderValue,
    required this.preparationTime,
    this.distance,
  });

  bool get isOpen => openingHours.isOpenNow();

  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Conversion sécurisée de l'adresse depuis la structure 'companys'
    RestaurantAddress address;
    if (data['adress'] != null && data['adress'] is Map) {
      final adressData = data['adress'] as Map<String, dynamic>;
      address = RestaurantAddress(
        address: adressData['adresse']?.toString() ?? '',
        codePostal: adressData['code_postal']?.toString() ?? adressData['codePostal']?.toString() ?? '',
        ville: adressData['ville']?.toString() ?? '',
        pays: adressData['pays']?.toString() ?? 'France',
        latitude: _parseDouble(adressData['latitude']) ?? 0.0,
        longitude: _parseDouble(adressData['longitude']) ?? 0.0,
      );
    } else {
      address = RestaurantAddress(
        address: '',
        codePostal: '',
        ville: '',
        pays: 'France',
        latitude: 0.0,
        longitude: 0.0,
      );
    }

    // Conversion sécurisée des horaires depuis la structure 'companys'
    OpeningHours openingHours;
    if (data['openingHours'] != null && data['openingHours'] is Map) {
      final hoursData = Map<String, String>.from(
        (data['openingHours'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? 'fermé'),
        ),
      );
      openingHours = OpeningHours(schedule: hoursData);
    } else {
      openingHours = OpeningHours(schedule: {});
    }

    // Conversion sécurisée de la galerie
    List<String> gallery = [];
    if (data['gallery'] != null) {
      if (data['gallery'] is List) {
        gallery = (data['gallery'] as List).map((item) {
          if (item is Map && item['url'] != null) {
            return item['url'].toString();
          }
          return item.toString();
        }).toList();
      } else if (data['gallery'] is String) {
        gallery = [data['gallery']];
      }
    }

    // Conversion sécurisée du rating
    double rating = 0.0;
    if (data['averageRating'] != null) {
      rating = _parseDouble(data['averageRating']) ?? 0.0;
    } else if (data['rating'] != null) {
      rating = _parseDouble(data['rating']) ?? 0.0;
    }

    // Conversion sécurisée du nombre d'avis
    int totalReviews = 0;
    if (data['numberOfReviews'] != null) {
      totalReviews = _parseInt(data['numberOfReviews']) ?? 0;
    } else if (data['totalReviews'] != null) {
      totalReviews = _parseInt(data['totalReviews']) ?? 0;
    }

    return Restaurant(
      id: doc.id,
      companyId: doc.id, // Dans companys, l'ID du document est l'ID de la company
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
      sortOrder: _parseInt(data['sortOrder']) ?? 0,
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      website: data['website']?.toString() ?? '',
      address: address,
      logo: data['logo']?.toString() ?? '',
      cover: data['cover']?.toString() ?? '',
      gallery: gallery,
      openingHours: openingHours,
      socialMedia: SocialMedia(), // Pas de données sociales dans companys
      tags: _parseTags(data['categorie']?.toString()),
      rating: rating,
      totalReviews: totalReviews,
      category: data['categorie']?.toString() ?? '',
      subCategory: data['type']?.toString() ?? '',
      deliveryRange: _parseDouble(data['deliveryRange']) ?? 5.0,
      averageOrderValue: _parseDouble(data['averageOrderValue']) ?? 25.0,
      preparationTime: _parseInt(data['preparationTime']) ?? 30,
    );
  }

  // Méthodes utilitaires pour la conversion sécurisée de types
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<String> _parseTags(String? category) {
    if (category == null || category.isEmpty) return [];
    return [category, 'Restauration'];
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'name': name,
      'description': description,
      'email': email,
      'phone': phone,
      'website': website,
      'address': address.toMap(),
      'logo': logo,
      'cover': cover,
      'gallery': gallery,
      'openingHours': openingHours.toMap(),
      'socialMedia': socialMedia.toMap(),
      'tags': tags,
      'rating': rating,
      'totalReviews': totalReviews,
      'category': category,
      'subCategory': subCategory,
      'deliveryRange': deliveryRange,
      'averageOrderValue': averageOrderValue,
      'preparationTime': preparationTime,
    };
  }
}

class MenuCategory extends BaseEntity {
  final String name;
  final String description;
  final String? image;

  MenuCategory({
    required super.id,
    required super.companyId,
    required super.createdAt,
    super.updatedAt,
    super.isActive,
    super.sortOrder,
    required this.name,
    required this.description,
    this.image,
  });

  factory MenuCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MenuCategory(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      isActive: data['isActive'] ?? true,
      sortOrder: data['sortOrder'] ?? 0,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      image: data['image'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'name': name,
      'description': description,
      'image': image,
    };
  }
} 