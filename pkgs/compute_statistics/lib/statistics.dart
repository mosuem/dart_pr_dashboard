import 'dart:convert';

import 'package:github/github.dart';

typedef Month = int;
typedef Priority = int;

class Statistics {
  final Map<Month, Duration> timeToLabelPerMonth;
  final Map<Month, (int unlabeled, int total)> unlabeledIssuesPerMonth;
  final List<Issue> p0Issues;
  final List<Issue> p1Issues;
  final List<Issue> importantP2Issues;
  final List<Issue> topVotedIssues;
  final Map<Month, Map<Priority, Duration>> responseRatePerMonthAndPriority;

  Statistics({
    required this.timeToLabelPerMonth,
    required this.unlabeledIssuesPerMonth,
    required this.p0Issues,
    required this.p1Issues,
    required this.importantP2Issues,
    required this.topVotedIssues,
    required this.responseRatePerMonthAndPriority,
  });

  Map<String, dynamic> toMap() {
    return {
      'timeToLabelPerMonth': timeToLabelPerMonth.map((key, value) => MapEntry(
            key.toString(),
            value.inMilliseconds,
          )),
      'unlabeledIssuesPerMonth': unlabeledIssuesPerMonth
          .map((key, value) => MapEntry(key.toString(), [value.$1, value.$2])),
      'p0Issues': p0Issues.map((x) => x.toJson()).toList(),
      'p1Issues': p1Issues.map((x) => x.toJson()).toList(),
      'importantP2Issues': importantP2Issues.map((x) => x.toJson()).toList(),
      'topVotedIssues': topVotedIssues.map((x) => x.toJson()).toList(),
      'responseRatePerMonthAndPriority':
          responseRatePerMonthAndPriority.map((key, value) => MapEntry(
                key.toString(),
                value.map((key, value) => MapEntry(
                      key.toString(),
                      value.inMilliseconds,
                    )),
              )),
    };
  }

  factory Statistics.fromMap(Map<String, dynamic> map) {
    return Statistics(
      timeToLabelPerMonth: toMonthDurationMap(map['timeToLabelPerMonth']),
      unlabeledIssuesPerMonth:
          (map['unlabeledIssuesPerMonth'] as Map<String, dynamic>).map(
              (key, value) =>
                  MapEntry(int.parse(key), (value.first, value.last))),
      p0Issues:
          List<Issue>.from(map['p0Issues']?.map((x) => Issue.fromJson(x))),
      p1Issues:
          List<Issue>.from(map['p1Issues']?.map((x) => Issue.fromJson(x))),
      importantP2Issues: List<Issue>.from(
          map['importantP2Issues']?.map((x) => Issue.fromJson(x))),
      topVotedIssues: List<Issue>.from(
          map['topVotedIssues']?.map((x) => Issue.fromJson(x))),
      responseRatePerMonthAndPriority:
          (map['responseRatePerMonthAndPriority'] as Map<String, dynamic>).map(
              (key, value) =>
                  MapEntry(int.parse(key), toMonthDurationMap(value))),
    );
  }

  static Map<Month, Duration> toMonthDurationMap(Map<String, dynamic> map) =>
      (map).map((key, value) =>
          MapEntry(int.parse(key), Duration(milliseconds: value)));

  String toJson() => json.encode(toMap());

  factory Statistics.fromJson(String source) =>
      Statistics.fromMap(json.decode(source));
}
