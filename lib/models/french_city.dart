class FrenchCity {
  final String inseeCode;
  final String cityCode;
  final String zipCode;
  final String label;
  final double latitude;
  final double longitude;
  final String departmentName;
  final String departmentNumber;
  final String regionName;

  FrenchCity({
    required this.inseeCode,
    required this.cityCode,
    required this.zipCode,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.departmentName,
    required this.departmentNumber,
    required this.regionName,
  });

  factory FrenchCity.fromJson(Map<String, dynamic> json) {
    return FrenchCity(
      inseeCode: json['insee_code'],
      cityCode: json['city_code'],
      zipCode: json['zip_code'],
      label: json['label'],
      latitude: double.parse(json['latitude']),
      longitude: double.parse(json['longitude']),
      departmentName: json['department_name'],
      departmentNumber: json['department_number'],
      regionName: json['region_name'],
    );
  }
}
