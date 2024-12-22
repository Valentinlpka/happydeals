import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final int level;
  final String? parentId;
  final bool hasAttributes;

  Category({
    required this.id,
    required this.name,
    required this.level,
    this.parentId,
    this.hasAttributes = false,
  });

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  factory Category.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Category(
      id: doc.id,
      name: data['name'] ?? '',
      parentId: data['parentId'],
      level: data['level'] ?? 1,
      hasAttributes: data['hasAttributes'] ?? false,
    );
  }
}

class CategoryAttribute {
  final String name;
  final String type;
  final bool required;
  final List<String> values;

  CategoryAttribute({
    required this.name,
    required this.type,
    required this.required,
    required this.values,
  });

  factory CategoryAttribute.fromMap(Map<String, dynamic> map) {
    return CategoryAttribute(
      name: map['name'] ?? '',
      type: map['type'] ?? 'select',
      required: map['required'] ?? false,
      values: List<String>.from(map['values'] ?? []),
    );
  }
}

class CategoryAttributes {
  final String categoryId;
  final List<CategoryAttribute> attributes;

  CategoryAttributes({
    required this.categoryId,
    required this.attributes,
  });

  factory CategoryAttributes.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return CategoryAttributes(
      categoryId: doc.id,
      attributes: (data['attributes'] as List<dynamic>? ?? [])
          .map((attr) => CategoryAttribute.fromMap(attr))
          .toList(),
    );
  }
}
