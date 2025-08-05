import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItemAvailability {
  final bool canBeSoldAlone;
  final bool canBeInMenu;
  final bool canBeAddon;
  final bool canBeReplacement;

  MenuItemAvailability({
    required this.canBeSoldAlone,
    required this.canBeInMenu,
    required this.canBeAddon,
    required this.canBeReplacement,
  });

  factory MenuItemAvailability.fromMap(Map<String, dynamic> map) {
    return MenuItemAvailability(
      canBeSoldAlone: map['canBeSoldAlone'] ?? true,
      canBeInMenu: map['canBeInMenu'] ?? true,
      canBeAddon: map['canBeAddon'] ?? false,
      canBeReplacement: map['canBeReplacement'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canBeSoldAlone': canBeSoldAlone,
      'canBeInMenu': canBeInMenu,
      'canBeAddon': canBeAddon,
      'canBeReplacement': canBeReplacement,
    };
  }
}

class DisplaySettings {
  final bool hideWhenPartOfMenu;
  final bool showInMainMenu;
  final List<String> showInCategories;

  DisplaySettings({
    required this.hideWhenPartOfMenu,
    required this.showInMainMenu,
    required this.showInCategories,
  });

  factory DisplaySettings.fromMap(Map<String, dynamic> map) {
    return DisplaySettings(
      hideWhenPartOfMenu: map['hideWhenPartOfMenu'] ?? false,
      showInMainMenu: map['showInMainMenu'] ?? true,
      showInCategories: List<String>.from(map['showInCategories'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hideWhenPartOfMenu': hideWhenPartOfMenu,
      'showInMainMenu': showInMainMenu,
      'showInCategories': showInCategories,
    };
  }
}

class NutritionInfo {
  final int calories;
  final List<String> allergens;
  final bool isVegetarian;
  final bool isVegan;

  NutritionInfo({
    required this.calories,
    required this.allergens,
    required this.isVegetarian,
    required this.isVegan,
  });

  factory NutritionInfo.fromMap(Map<String, dynamic> map) {
    return NutritionInfo(
      calories: map['calories'] ?? 0,
      allergens: List<String>.from(map['allergens'] ?? []),
      isVegetarian: map['isVegetarian'] ?? false,
      isVegan: map['isVegan'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'allergens': allergens,
      'isVegetarian': isVegetarian,
      'isVegan': isVegan,
    };
  }
}

class MenuItem {
  final String id;
  final String companyId;
  final String restaurantId;
  final String categoryId;
  final String name;
  final String description;
  final List<String> images;
  final double basePrice;
  final int preparationTime;
  final MenuItemAvailability availability;
  final DisplaySettings displaySettings;
  final NutritionInfo nutrition;
  final List<String> tags;
  final bool isActive;
  final bool isAvailable;
  final int sortOrder;
  final DateTime createdAt;

  MenuItem({
    required this.id,
    required this.companyId,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.images,
    required this.basePrice,
    required this.preparationTime,
    required this.availability,
    required this.displaySettings,
    required this.nutrition,
    required this.tags,
    required this.isActive,
    required this.isAvailable,
    required this.sortOrder,
    required this.createdAt,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return MenuItem(
      id: doc.id,
      companyId: data['companyId']?.toString() ?? '',
      restaurantId: data['restaurantId']?.toString() ?? '',
      categoryId: data['categoryId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      images: List<String>.from(data['images'] ?? []),
      basePrice: _parseDouble(data['basePrice']) ?? 0.0,
      preparationTime: _parseInt(data['preparationTime']) ?? 0,
      availability: MenuItemAvailability.fromMap(data['availability'] ?? {}),
      displaySettings: DisplaySettings.fromMap(data['displaySettings'] ?? {}),
      nutrition: NutritionInfo.fromMap(data['nutrition'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      isActive: data['isActive'] ?? true,
      isAvailable: data['isAvailable'] ?? true,
      sortOrder: _parseInt(data['sortOrder']) ?? 0,
      createdAt: data['createdAt'] is String
          ? DateTime.parse(data['createdAt'])
          : data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'restaurantId': restaurantId,
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'images': images,
      'basePrice': basePrice,
      'preparationTime': preparationTime,
      'availability': availability.toMap(),
      'displaySettings': displaySettings.toMap(),
      'nutrition': nutrition.toMap(),
      'tags': tags,
      'isActive': isActive,
      'isAvailable': isAvailable,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

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
}

class RestaurantMenuCategory {
  final String id;
  final String companyId;
  final String name;
  final int order;

  RestaurantMenuCategory({
    required this.id,
    required this.companyId,
    required this.name,
    required this.order,
  });

  factory RestaurantMenuCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RestaurantMenuCategory(
      id: doc.id,
      companyId: data['companyId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      order: (data['order'] ?? 0) is int ? data['order'] : int.tryParse(data['order'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'name': name,
      'order': order,
    };
  }
}

class MainItem {
  final String itemId;
  final bool includeItemVariants;
  final int quantity;

  MainItem({
    required this.itemId,
    required this.includeItemVariants,
    required this.quantity,
  });

  factory MainItem.fromMap(Map<String, dynamic> map) {
    return MainItem(
      itemId: map['itemId']?.toString() ?? '',
      includeItemVariants: map['includeItemVariants'] ?? true,
      quantity: (map['quantity'] ?? 1) is int ? map['quantity'] : int.tryParse(map['quantity'].toString()) ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'includeItemVariants': includeItemVariants,
      'quantity': quantity,
    };
  }
}

class RestaurantMenu {
  final String id;
  final String companyId;
  final String restaurantId;
  final String categoryId;
  final String name;
  final String description;
  final List<String> images;
  final double basePrice;
  final String menuTemplateId;
  final MainItem mainItem;
  final Map<String, dynamic> templateOverrides;
  final DisplaySettings displaySettings;
  final List<String> tags;
  final bool isActive;
  final bool isAvailable;
  final int sortOrder;
  final DateTime createdAt;

  RestaurantMenu({
    required this.id,
    required this.companyId,
    required this.restaurantId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.images,
    required this.basePrice,
    required this.menuTemplateId,
    required this.mainItem,
    required this.templateOverrides,
    required this.displaySettings,
    required this.tags,
    required this.isActive,
    required this.isAvailable,
    required this.sortOrder,
    required this.createdAt,
  });

  factory RestaurantMenu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RestaurantMenu(
      id: doc.id,
      companyId: data['companyId']?.toString() ?? '',
      restaurantId: data['restaurantId']?.toString() ?? '',
      categoryId: data['categoryId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      images: List<String>.from(data['images'] ?? []),
      basePrice: _parseDouble(data['basePrice']) ?? 0.0,
      menuTemplateId: data['menuTemplateId']?.toString() ?? '',
      mainItem: MainItem.fromMap(data['mainItem'] ?? {}),
      templateOverrides: Map<String, dynamic>.from(data['templateOverrides'] ?? {}),
      displaySettings: DisplaySettings.fromMap(data['displaySettings'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      isActive: data['isActive'] ?? true,
      isAvailable: data['isAvailable'] ?? true,
      sortOrder: _parseInt(data['sortOrder']) ?? 0,
      createdAt: data['createdAt'] is String
          ? DateTime.parse(data['createdAt'])
          : data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

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
}

enum PromotionType { percentage, fixedAmount, specialPrice }

class PromotionSchedule {
  final String type;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? daysOfWeek;
  final List<TimeRange>? timeRanges;

  PromotionSchedule({
    required this.type,
    this.startDate,
    this.endDate,
    this.daysOfWeek,
    this.timeRanges,
  });

  factory PromotionSchedule.fromMap(Map<String, dynamic> map) {
    List<String>? daysOfWeek;
    if (map['daysOfWeek'] != null) {
      daysOfWeek = List<String>.from(map['daysOfWeek']);
    }
    
    List<TimeRange>? timeRanges;
    if (map['timeRanges'] != null) {
      timeRanges = (map['timeRanges'] as List)
          .map((tr) => TimeRange.fromMap(tr as Map<String, dynamic>))
          .toList();
    }
    
    return PromotionSchedule(
      type: map['type']?.toString() ?? 'always',
      startDate: map['startDate'] is String 
          ? DateTime.parse(map['startDate'])
          : map['startDate'] is Timestamp
              ? (map['startDate'] as Timestamp).toDate()
              : null,
      endDate: map['endDate'] is String
          ? DateTime.parse(map['endDate'])
          : map['endDate'] is Timestamp
              ? (map['endDate'] as Timestamp).toDate()
              : null,
      daysOfWeek: daysOfWeek,
      timeRanges: timeRanges,
    );
  }
}

class TimeRange {
  final String start;
  final String end;

  TimeRange({
    required this.start,
    required this.end,
  });

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    return TimeRange(
      start: map['start']?.toString() ?? '',
      end: map['end']?.toString() ?? '',
    );
  }
}

class PromotionConditions {
  final double? minimumAmount;
  final int? minimumItems;
  final List<String>? applicableCategoryIds;
  final List<String>? applicableItemIds;
  final List<String>? applicableMenuIds;

  PromotionConditions({
    this.minimumAmount,
    this.minimumItems,
    this.applicableCategoryIds,
    this.applicableItemIds,
    this.applicableMenuIds,
  });

  factory PromotionConditions.fromMap(Map<String, dynamic> map) {
    return PromotionConditions(
      minimumAmount: _parseDouble(map['minimumAmount']),
      minimumItems: _parseInt(map['minimumItems']),
      applicableCategoryIds: map['applicableCategoryIds'] != null 
          ? List<String>.from(map['applicableCategoryIds']) 
          : null,
      applicableItemIds: map['applicableItemIds'] != null 
          ? List<String>.from(map['applicableItemIds']) 
          : null,
      applicableMenuIds: map['applicableMenuIds'] != null 
          ? List<String>.from(map['applicableMenuIds']) 
          : null,
    );
  }

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
}

class RestaurantPromotion {
  final String id;
  final String companyId;
  final String name;
  final String description;
  final PromotionType type;
  final double value;
  final PromotionSchedule schedule;
  final PromotionConditions? conditions;
  final bool stackable;
  final bool active;
  final int priority;
  final int sortOrder;
  final DateTime createdAt;

  RestaurantPromotion({
    required this.id,
    required this.companyId,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.schedule,
    this.conditions,
    required this.stackable,
    required this.active,
    required this.priority,
    required this.sortOrder,
    required this.createdAt,
  });

  factory RestaurantPromotion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    PromotionType getPromotionType(String? typeStr) {
      switch (typeStr) {
        case 'percentage':
          return PromotionType.percentage;
        case 'fixedAmount':
          return PromotionType.fixedAmount;
        case 'specialPrice':
          return PromotionType.specialPrice;
        default:
          return PromotionType.percentage;
      }
    }
    
    return RestaurantPromotion(
      id: doc.id,
      companyId: data['companyId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      type: getPromotionType(data['type']?.toString()),
      value: _parseDouble(data['value']) ?? 0.0,
      schedule: PromotionSchedule.fromMap(data['schedule'] ?? {}),
      conditions: data['conditions'] != null 
          ? PromotionConditions.fromMap(data['conditions']) 
          : null,
      stackable: data['stackable'] ?? false,
      active: data['active'] ?? false,
      priority: _parseInt(data['priority']) ?? 0,
      sortOrder: _parseInt(data['sortOrder']) ?? 0,
      createdAt: data['createdAt'] is String
          ? DateTime.parse(data['createdAt'])
          : data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

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

  bool isValidNow() {
    if (!active) return false;

    final now = DateTime.now();
    
    switch (schedule.type) {
      case 'date_range':
        if (schedule.startDate != null && now.isBefore(schedule.startDate!)) return false;
        if (schedule.endDate != null && now.isAfter(schedule.endDate!)) return false;
        break;
        
      case 'weekly':
        // Vérifier le jour de la semaine
        if (schedule.daysOfWeek != null && schedule.daysOfWeek!.isNotEmpty) {
          final currentDayName = _getCurrentDayName(now.weekday);
          if (!schedule.daysOfWeek!.contains(currentDayName)) {
            return false; // Pas le bon jour de la semaine
          }
        }
        // Vérifier aussi les heures si spécifiées
        if (schedule.timeRanges != null) {
          final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          bool inTimeRange = false;
          for (final range in schedule.timeRanges!) {
            if (currentTime.compareTo(range.start) >= 0 && currentTime.compareTo(range.end) <= 0) {
              inTimeRange = true;
              break;
            }
          }
          if (!inTimeRange) {
            return false;
          }
        }
        break;
        
      case 'daily':
        // Pour les promotions quotidiennes, vérifier seulement les heures
        if (schedule.timeRanges != null) {
          final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          bool inTimeRange = false;
          for (final range in schedule.timeRanges!) {
            if (currentTime.compareTo(range.start) >= 0 && currentTime.compareTo(range.end) <= 0) {
              inTimeRange = true;
              break;
            }
          }
          if (!inTimeRange) {
            return false;
          }
        }
        break;
        
      case 'always':
      default:
        // Toujours valide si active
        break;
    }

    return true;
  }

  String _getCurrentDayName(int weekday) {
    const days = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday'
    ];
    return days[weekday - 1];
  }

  double calculateDiscount(double amount) {
    if (!isValidNow()) return 0.0;
    
    switch (type) {
      case PromotionType.percentage:
        return amount * (value / 100);
      case PromotionType.fixedAmount:
        return value;
      case PromotionType.specialPrice:
        return amount - value;
    }
  }
} 

// Classes pour les templates de menus
class Template {
  final String id;
  final String name;
  final String type; // 'menu' ou 'variant'
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Template({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  factory Template.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Template(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class MenuTemplate extends Template {
  final bool includeItemVariants;
  final List<IncludedVariantTemplate> includedVariantTemplates;

  MenuTemplate({
    required super.id,
    required super.name,
    required super.type,
    required super.isActive,
    required super.createdAt,
    super.updatedAt,
    required this.includeItemVariants,
    required this.includedVariantTemplates,
  });

  factory MenuTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    List<IncludedVariantTemplate> templates = [];
    if (data['includedVariantTemplates'] != null) {
      templates = (data['includedVariantTemplates'] as List)
          .map((t) => IncludedVariantTemplate.fromMap(t as Map<String, dynamic>))
          .toList();
    }

    return MenuTemplate(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? 'menu',
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      includeItemVariants: data['includeItemVariants'] ?? false,
      includedVariantTemplates: templates,
    );
  }
}

class IncludedVariantTemplate {
  final String templateId;
  final String? label;
  final int order;
  final bool isRequired;

  IncludedVariantTemplate({
    required this.templateId,
    this.label,
    required this.order,
    required this.isRequired,
  });

  factory IncludedVariantTemplate.fromMap(Map<String, dynamic> map) {
    return IncludedVariantTemplate(
      templateId: map['templateId']?.toString() ?? '',
      label: map['label']?.toString(),
      order: map['order'] ?? 0,
      isRequired: map['isRequired'] ?? false,
    );
  }
}

class VariantTemplate extends Template {
  final List<ReferencedItem> referencedItems;

  VariantTemplate({
    required super.id,
    required super.name,
    required super.type,
    required super.isActive,
    required super.createdAt,
    super.updatedAt,
    required this.referencedItems,
  });

  factory VariantTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    List<ReferencedItem> items = [];
    if (data['referencedItems'] != null) {
      items = (data['referencedItems'] as List)
          .map((i) => ReferencedItem.fromMap(i as Map<String, dynamic>))
          .toList();
    }

    return VariantTemplate(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? 'variant',
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      referencedItems: items,
    );
  }
}

class ReferencedItem {
  final String itemId;
  final String displayName;
  final bool isDefault;

  ReferencedItem({
    required this.itemId,
    required this.displayName,
    required this.isDefault,
  });

  factory ReferencedItem.fromMap(Map<String, dynamic> map) {
    return ReferencedItem(
      itemId: map['itemId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      isDefault: map['isDefault'] ?? false,
    );
  }
}



class TemplateOverride {
  final Map<String, double>? priceOverrides;
  final Map<String, String>? displayOverrides;

  TemplateOverride({
    this.priceOverrides,
    this.displayOverrides,
  });

  factory TemplateOverride.fromMap(Map<String, dynamic> map) {
    Map<String, double>? priceOverrides;
    if (map['priceOverrides'] != null) {
      priceOverrides = {};
      final priceData = map['priceOverrides'] as Map<String, dynamic>;
      priceData.forEach((key, value) {
        priceOverrides![key] = (value ?? 0).toDouble();
      });
    }

    Map<String, String>? displayOverrides;
    if (map['displayOverrides'] != null) {
      displayOverrides = Map<String, String>.from(map['displayOverrides']);
    }

    return TemplateOverride(
      priceOverrides: priceOverrides,
      displayOverrides: displayOverrides,
    );
  }
}

// Helper functions
bool isMenuTemplate(Template template) {
  return template is MenuTemplate;
}

bool isVariantTemplate(Template template) {
  return template is VariantTemplate;
} 