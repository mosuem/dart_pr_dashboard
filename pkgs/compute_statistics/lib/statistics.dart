import 'package:dart_triage_updater/firebase_database.dart';
import 'package:dart_triage_updater/issue_utils.dart';
import 'package:github/github.dart';

typedef Month = int;
typedef Priority = int;

class Statistics {
  final DateTime timeStamp;
  final Map<Month, Duration> timeToLabelPerMonth;
  final Map<Month, (int unlabeled, int total)> unlabeledIssuesPerMonth;
  final List<Issue> p0Issues;
  final List<Issue> p1Issues;
  final List<Issue> importantP2Issues;
  final List<PullRequest> p0PullRequests;
  final List<PullRequest> p1PullRequests;
  final List<Issue> topVotedIssues;
  final Map<Month, Map<Priority, Duration>> updateFrequencyPerMonthAndPriority;
  final Map<RepositorySlug, (int unlabeled, int total)>
      repositoriesWithMostUntriaged;

  Statistics({
    required this.timeStamp,
    required this.timeToLabelPerMonth,
    required this.unlabeledIssuesPerMonth,
    required this.p0Issues,
    required this.p1Issues,
    required this.importantP2Issues,
    required this.p0PullRequests,
    required this.p1PullRequests,
    required this.topVotedIssues,
    required this.updateFrequencyPerMonthAndPriority,
    required this.repositoriesWithMostUntriaged,
  });

  Map<String, dynamic> toJson() {
    return {
      'timeStamp': timeStamp.millisecondsSinceEpoch,
      'timeToLabelPerMonth': timeToLabelPerMonth.map((key, value) => MapEntry(
            key.toString(),
            value.inMilliseconds,
          )),
      'unlabeledIssuesPerMonth': unlabeledIssuesPerMonth
          .map((key, value) => MapEntry(key.toString(), [value.$1, value.$2])),
      'p0Issues': p0Issues.map((x) => x.toJson()).toList(),
      'p1Issues': p1Issues.map((x) => x.toJson()).toList(),
      'importantP2Issues': importantP2Issues.map((x) => x.toJson()).toList(),
      'p0PullRequests': p0Issues.map((x) => x.toJson()).toList(),
      'p1PullRequests': p1Issues.map((x) => x.toJson()).toList(),
      'topVotedIssues': topVotedIssues.map((x) => x.toJson()).toList(),
      'responseRatePerMonthAndPriority':
          updateFrequencyPerMonthAndPriority.map((key, value) => MapEntry(
                key.toString(),
                value.map((key, value) => MapEntry(
                      key.toString(),
                      value.inMilliseconds,
                    )),
              )),
      'repositoriesWithMostUntriaged': repositoriesWithMostUntriaged
          .map((key, value) => MapEntry(key.toUrl(), [value.$1, value.$2])),
    };
  }

  factory Statistics.fromJson(Map<String, dynamic> map) {
    return Statistics(
      timeStamp: DateTime.fromMillisecondsSinceEpoch(map['timeStamp']),
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
      p0PullRequests: List<PullRequest>.from(
          map['p0PullRequests']?.map((x) => PullRequest.fromJson(x))),
      p1PullRequests: List<PullRequest>.from(
          map['p1PullRequests']?.map((x) => PullRequest.fromJson(x))),
      topVotedIssues: List<Issue>.from(
          map['topVotedIssues']?.map((x) => Issue.fromJson(x))),
      updateFrequencyPerMonthAndPriority:
          (map['responseRatePerMonthAndPriority'] as Map<String, dynamic>).map(
              (key, value) =>
                  MapEntry(int.parse(key), toMonthDurationMap(value))),
      repositoriesWithMostUntriaged: (map['repositoriesWithMostUntriaged']
              as Map<String, dynamic>)
          .map((key, value) => MapEntry(
              RepositorySlugExtension.fromUrl(key), (value.first, value.last))),
    );
  }

  static Map<Month, Duration> toMonthDurationMap(Map<String, dynamic> map) =>
      map.map((key, value) =>
          MapEntry(int.parse(key), Duration(milliseconds: value)));

  //TODO: Make this a markdown
  String toReport() {
    return '''
timeToLabelPerMonth:\n$timeToLabelPerMonth
unlabeledIssuesPerMonth:\n${unlabeledIssuesPerMonth.map((key, value) => MapEntry(key, (value.$1 / value.$2).toStringAsPrecision(3)))}
p0Issues:\n${p0Issues.length}
p1Issues:\n${p1Issues.length}
importantP2Issues:\n${importantP2Issues.map((e) => (
              e.repoSlug!.name,
              e.title,
              e.upvotes
            )).join('\n')}
p0PullRequests:\n${p0PullRequests.length}
p1PullRequests:\n${p1PullRequests.length}
topVotedIssues:\n${topVotedIssues.map((e) => (
              e.repoSlug!.name,
              e.title,
              e.upvotes
            )).join('\n')}
updateFrequencyPerMonthAndPriority:\n$updateFrequencyPerMonthAndPriority
repositoriesWithMostUntriaged:\n${repositoriesWithMostUntriaged.entries.map((e) => '${e.key.name}:${(e.value.$1 / e.value.$2).toStringAsPrecision(3)}').join('\n')}
''';
  }
}
