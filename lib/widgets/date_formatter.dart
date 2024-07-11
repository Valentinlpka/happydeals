import 'package:intl/intl.dart';

String formatDateTime(DateTime dateTime) {
  return DateFormat('dd/MM/yyyy', 'fr_FR')
      .format(dateTime); // Format comme "2024-06-13"
}
