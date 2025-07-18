class TechnicalDetail {
  final String key;
  final String value;
  final String? icon;

  TechnicalDetail({
    required this.key,
    required this.value,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'icon': icon,
    };
  }

  factory TechnicalDetail.fromMap(Map<String, dynamic> map) {
    return TechnicalDetail(
      key: map['key'] ?? '',
      value: map['value'] ?? '',
      icon: map['icon'],
    );
  }
} 