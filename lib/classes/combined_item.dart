import 'package:happy/classes/company.dart';

class CombinedItem {
  final dynamic item;
  final DateTime timestamp;
  final String type;

  CombinedItem(this.item, this.timestamp, this.type);

  factory CombinedItem.fromPost(Map<String, dynamic> postData) {
    return CombinedItem(postData, postData['post'].timestamp, 'post');
  }

  factory CombinedItem.fromCompany(Company company) {
    return CombinedItem(company, company.createdAt, 'company');
  }
}

// Le CombinedPagingController n'est plus nécessaire car nous chargeons toutes les données en une seule fois.