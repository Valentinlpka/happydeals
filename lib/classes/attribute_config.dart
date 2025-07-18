class AttributeConfig {
  final String name;
  final bool requiresImage;

  AttributeConfig({
    required this.name,
    required this.requiresImage,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'requiresImage': requiresImage,
    };
  }

  factory AttributeConfig.fromMap(Map<String, dynamic> map) {
    return AttributeConfig(
      name: map['name'] ?? '',
      requiresImage: map['requiresImage'] ?? false,
    );
  }
} 