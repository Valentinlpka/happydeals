import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TimeRange {
  final int hours;
  final int minutes;

  const TimeRange(this.hours, this.minutes);

  Map<String, dynamic> toMap() => {
        'hours': hours,
        'minutes': minutes,
      };

  factory TimeRange.fromMap(Map<String, dynamic> map) {
    try {
      return TimeRange(
        map['hours'] as int? ?? 0,
        map['minutes'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('Erreur dans TimeRange.fromMap: $e');
      debugPrint('Données: $map');
      rethrow;
    }
  }
}

class AvailabilityRuleModel {
  final String id;
  final String professionalId;
  final String serviceId;
  final List<int> workDays;
  final TimeRange startTime;
  final TimeRange endTime;
  final List<BreakTime> breakTimes;
  final List<DateTime> exceptionalClosedDates;
  final List<ExceptionalDate> exceptionalDates;
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
    this.exceptionalDates = const [],
    this.isActive = true,
  });

  factory AvailabilityRuleModel.fromMap(Map<String, dynamic> map) {
    try {
      debugPrint('Données reçues: $map'); // Debug
      return AvailabilityRuleModel(
        id: map['id'] ?? '',
        professionalId: map['professionalId'] ?? '',
        serviceId: map['serviceId'] ?? '',
        workDays: List<int>.from(map['workDays'] ?? []),
        startTime:
            TimeRange.fromMap(map['startTime'] ?? {'hours': 9, 'minutes': 0}),
        endTime:
            TimeRange.fromMap(map['endTime'] ?? {'hours': 18, 'minutes': 0}),
        breakTimes: (map['breakTimes'] as List?)
                ?.map((bt) => BreakTime.fromMap(bt))
                .toList() ??
            [],
        exceptionalClosedDates: (map['exceptionalClosedDates'] as List?)
                ?.map((date) => (date as Timestamp).toDate())
                .toList() ??
            [],
        exceptionalDates: (map['exceptionalDates'] as List?)
                ?.map((e) => ExceptionalDate.fromMap(e))
                .toList() ??
            [],
        isActive: map['isActive'] ?? true,
      );
    } catch (e, stackTrace) {
      debugPrint('Erreur dans fromMap: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Données problématiques: $map');
      rethrow;
    }
  }
}

class ExceptionalDate {
  final DateTime date;
  final String type;
  final String? note;

  ExceptionalDate({required this.date, required this.type, this.note});

  factory ExceptionalDate.fromMap(Map<String, dynamic> map) {
    return ExceptionalDate(
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] as String,
      note: map['note'] as String?,
    );
  }
}

class BreakTime {
  final TimeRange start;
  final TimeRange end;

  const BreakTime({required this.start, required this.end});

  factory BreakTime.fromMap(Map<String, dynamic> map) {
    try {
      return BreakTime(
        start: TimeRange.fromMap(map['start'] ?? {}),
        end: TimeRange.fromMap(map['end'] ?? {}),
      );
    } catch (e) {
      debugPrint('Erreur dans BreakTime.fromMap: $e');
      debugPrint('Données: $map');
      rethrow;
    }
  }
}
