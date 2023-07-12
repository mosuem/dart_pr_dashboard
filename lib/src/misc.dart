import 'package:flutter/material.dart';
import 'package:github/github.dart';

final noTime = DateTime.fromMillisecondsSinceEpoch(0);

const gWithCircle = 'goog';

String daysSince(DateTime? dt) {
  if (dt == null) return '';
  final d = DateTime.now().difference(dt);
  return d.inDays.toString();
}

String formatUsername(User? user, List<User> googlers) {
  final googlerMark = googlers.any((googler) => googler.login == user?.login)
      ? ' ($gWithCircle)'
      : '';
  return '@${user?.login ?? ''}$googlerMark';
}

int compareDates(DateTime? a, DateTime? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

bool isLightColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.light;
