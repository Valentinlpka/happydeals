class Category {
  final String name;
  final List<String> subCategories;

  Category({required this.name, required this.subCategories});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['nom'],
      subCategories: List<String>.from(json['sous-catégories']),
    );
  }
}
