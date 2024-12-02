// lib/models/availability_rule_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeRange {
  final int hours;
  final int minutes;

  const TimeRange(this.hours, this.minutes);

  Map<String, dynamic> toMap() => {
        'hours': hours,
        'minutes': minutes,
      };

  factory TimeRange.fromMap(Map<String, dynamic> map) => TimeRange(
        map['hours'] as int,
        map['minutes'] as int,
      );
}

class AvailabilityRuleModel {
  final String id;
  final String professionalId;
  final String serviceId;
  final List<int> workDays;
  final TimeRange startTime;
  final TimeRange endTime;
  final List<Map<String, TimeRange>> breakTimes;
  final List<DateTime> exceptionalClosedDates;
  final bool isActive;

  AvailabilityRuleModel({
    required this.id,
    required this.professionalId,
    required this.serviceId,
    required this.workDays,
    required this.startTime,
    required this.endTime,
    this.breakTimes = const [],
    this.exceptionalClosedDates = const [],
    this.isActive = true,
  });

  factory AvailabilityRuleModel.fromMap(Map<String, dynamic> map) {
    return AvailabilityRuleModel(
      id: map['id'],
      professionalId: map['professionalId'],
      serviceId: map['serviceId'],
      workDays: List<int>.from(map['workDays']),
      startTime: TimeRange.fromMap(map['startTime']),
      endTime: TimeRange.fromMap(map['endTime']),
      breakTimes: (map['breakTimes'] as List)
          .map((bt) => {
                'start': TimeRange.fromMap(bt['start']),
                'end': TimeRange.fromMap(bt['end']),
              })
          .toList(),
      exceptionalClosedDates: (map['exceptionalClosedDates'] as List)
          .map((date) => (date as Timestamp).toDate())
          .toList(),
      isActive: map['isActive'],
    );
  }
}
