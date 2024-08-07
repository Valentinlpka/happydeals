import 'package:accordion/accordion.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OpeningHoursWidget extends StatelessWidget {
  final Map<String, dynamic> openingHours;

  const OpeningHoursWidget({super.key, required this.openingHours});

  @override
  Widget build(BuildContext context) {
    bool isOpen = _isOpenNow(openingHours);
    String todayHours = _getTodayHours(openingHours);

    return Accordion(
      disableScrolling: true,
      paddingListTop: 5,
      paddingListBottom: 5,
      paddingListHorizontal: 0,
      headerBackgroundColor: Colors.white,
      rightIcon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
      flipRightIconIfOpen: true,
      headerBorderColor: Colors.grey[300],
      headerPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      headerBorderWidth: 1,
      contentBorderWidth: 1,
      headerBorderRadius: 3,
      contentBorderColor: Colors.grey[300],
      children: [
        AccordionSection(
          header: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOpen ? "Ouvert" : "Fermé",
                style: TextStyle(
                  color: isOpen ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                todayHours,
                style: const TextStyle(color: Colors.black),
              ),
            ],
          ),
          content: Column(
            children: _getSortedOpeningHours(openingHours).map((entry) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_getDayInFrench(entry.key)),
                  Text(entry.value),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  bool _isOpenNow(Map<String, dynamic> openingHours) {
    DateTime now = DateTime.now();
    String day = DateFormat('EEEE').format(now).toLowerCase();

    if (!openingHours.containsKey(day)) {
      return false;
    }

    String hours = openingHours[day];
    if (hours.toLowerCase() == 'fermé') {
      return false;
    }

    List<String> parts = hours.split(' - ');
    DateTime openTime = _parseTime(parts[0]);
    DateTime closeTime = _parseTime(parts[1]);

    return now.isAfter(openTime) && now.isBefore(closeTime);
  }

  DateTime _parseTime(String time) {
    DateTime now = DateTime.now();
    List<String> parts = time.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String _getDayInFrench(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 'Lundi';
      case 'tuesday':
        return 'Mardi';
      case 'wednesday':
        return 'Mercredi';
      case 'thursday':
        return 'Jeudi';
      case 'friday':
        return 'Vendredi';
      case 'saturday':
        return 'Samedi';
      case 'sunday':
        return 'Dimanche';
      default:
        return day;
    }
  }

  String _getTodayHours(Map<String, dynamic> openingHours) {
    String day = DateFormat('EEEE').format(DateTime.now()).toLowerCase();
    return openingHours[day] ?? 'Non renseigné';
  }

  List<MapEntry<String, dynamic>> _getSortedOpeningHours(
      Map<String, dynamic> openingHours) {
    const daysOfWeek = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    return openingHours.entries
        .where((entry) => daysOfWeek.contains(entry.key.toLowerCase()))
        .toList()
      ..sort((a, b) => daysOfWeek
          .indexOf(a.key.toLowerCase())
          .compareTo(daysOfWeek.indexOf(b.key.toLowerCase())));
  }
}
