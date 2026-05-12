import 'package:flutter/material.dart';

/// Parses "H:MM AM/PM - H:MM AM/PM" schedule strings and evaluates open/closed status.
class ScheduleParser {
  static final RegExp _scheduleRegex = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)\s*-\s*(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  );

  /// Returns null if the string is missing or doesn't match the expected format.
  static ({TimeOfDay open, TimeOfDay close})? parse(String? schedule) {
    if (schedule == null || schedule.isEmpty) return null;

    final match = _scheduleRegex.firstMatch(schedule.trim());
    if (match == null) return null;

    final open = TimeOfDay(
      hour: _to24Hour(
        int.parse(match.group(1)!),
        match.group(3)!.toUpperCase(),
      ),
      minute: int.parse(match.group(2)!),
    );
    final close = TimeOfDay(
      hour: _to24Hour(
        int.parse(match.group(4)!),
        match.group(6)!.toUpperCase(),
      ),
      minute: int.parse(match.group(5)!),
    );

    return (open: open, close: close);
  }

  // 12 AM → 0, 12 PM → 12, otherwise standard AM/PM conversion.
  static int _to24Hour(int hour, String period) {
    if (period == 'AM') return hour == 12 ? 0 : hour;
    return hour == 12 ? 12 : hour + 12;
  }

  /// Handles midnight-spanning ranges (e.g. 22:00–02:00) by checking
  /// whether close < open in total minutes.
  static bool isOpen(TimeOfDay open, TimeOfDay close, TimeOfDay now) {
    final openMin = open.hour * 60 + open.minute;
    final closeMin = close.hour * 60 + close.minute;
    final nowMin = now.hour * 60 + now.minute;

    if (closeMin < openMin) {
      // Overnight range — open if now >= open OR now <= close
      return nowMin >= openMin || nowMin <= closeMin;
    }
    return nowMin >= openMin && nowMin <= closeMin;
  }
}
