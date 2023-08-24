import 'dart:convert';

import 'package:dart_triage_updater/update_type.dart';

import 'statistics.dart';

class StatisticsType implements UpdateType<Statistics, Statistics> {
  @override
  DateTime createdAt(Statistics data) => data.timeStamp;

  @override
  Statistics decode(Object decoded) =>
      Statistics.fromJson(decoded as Map<String, dynamic>);

  @override
  Object encode(Statistics data) => jsonDecode(jsonEncode(data));

  @override
  String key(Statistics data) =>
      data.timeStamp.millisecondsSinceEpoch.toString();

  @override
  String get name => 'statistics';

  @override
  String get url => 'statistics';
}
