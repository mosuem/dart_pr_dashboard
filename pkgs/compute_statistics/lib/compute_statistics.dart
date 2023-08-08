import 'package:collection/collection.dart';
import 'package:dart_triage_updater/firebase_database.dart';
import 'package:dart_triage_updater/issue_utils.dart';
import 'package:dart_triage_updater/update_type.dart';
import 'package:github/github.dart';

import 'history.dart';
import 'statistics.dart';

class ComputeStatistics {
  final ref = DatabaseReference();
  final DateTime referenceDate;

  ComputeStatistics(this.referenceDate);

  Future<Statistics> compute() async {
    final createdAtMonth = await getCreatedAtMonth(referenceDate, IssueType());
    print(
        'createdAtMonth: ${createdAtMonth.map((key, value) => MapEntry(key, value.length))}');
    final openIssues = await getOpen(IssueType());
    print('openIssues: ${openIssues.length}');
    final openPullRequests = await getOpen(PullRequestType());
    print('openPullRequests: ${openPullRequests.length}');

    final statistics = Statistics(
      timeStamp: referenceDate,
      timeToLabelPerMonth: getTimeToLabel(createdAtMonth),
      unlabeledIssuesPerMonth: getUnlabeled(createdAtMonth),
      p0Issues: getPIssues(0, openIssues),
      p1Issues: getPIssues(1, openIssues),
      importantP2Issues: getUpvotedIssues(getPIssues(2, openIssues)),
      p0PullRequests: getPPullRequests(0, openPullRequests),
      p1PullRequests: getPPullRequests(1, openPullRequests),
      topVotedIssues: getUpvotedIssues(openIssues),
      updateFrequencyPerMonthAndPriority: {}, //TODO: think about what we want here
      repositoriesWithMostUntriaged: getUntriagedRepositories(openIssues),
    );
    print(statistics.toReport());
    return statistics;
  }

  List<Issue> getUpvotedIssues(List<Issue> issues) {
    return issues
        .sortedBy<num>((issue) => issue.upvotes)
        .reversed
        .take(5)
        .toList();
  }

  Map<int, (int, int)> getUnlabeled<T>(Map<int, List<History<T>>> diffs) {
    final timeToLabelPerMonth = <int, (int, int)>{};
    for (final diffInMonth in diffs.entries) {
      final month = diffInMonth.key;
      final toDate = getTo(month);
      var unlabeledCounter = 0;
      var totalCounter = 0;
      for (final diff in diffInMonth.value) {
        final wasLabeled = diff.wasLabeledAt(toDate);
        if (!wasLabeled) unlabeledCounter++;
        totalCounter++;
      }
      timeToLabelPerMonth[month] = (unlabeledCounter, totalCounter);
    }
    return timeToLabelPerMonth;
  }

  Map<int, Duration> getTimeToLabel<T>(Map<int, List<History<T>>> diffs) {
    final timeToLabelPerMonth = <int, Duration>{};
    for (final diffInMonth in diffs.entries) {
      var totalDuration = Duration.zero;
      var counter = 0;
      for (final diff in diffInMonth.value) {
        final timeToLabel = diff.timeToLabel;
        if (timeToLabel != null) {
          totalDuration += timeToLabel;
          counter++;
        }
      }
      timeToLabelPerMonth[diffInMonth.key] = counter > 0
          ? Duration(seconds: (totalDuration.inSeconds / counter).round())
          : Duration.zero;
    }
    return timeToLabelPerMonth;
  }

  Future<Map<int, List<History<T>>>> getCreatedAtMonth<T>(
    DateTime referenceDate,
    UpdateType<T, T> type,
  ) async {
    final diffs = <int, List<History<T>>>{};
    for (var i = 0; i < 12; i++) {
      final from = getFrom(i);
      final to = getTo(i);
      final issues = await ref.getAllWith(
        type,
        orderBy: 'created_at',
        startAt: from.millisecondsSinceEpoch.toString(),
        endAt: to.millisecondsSinceEpoch.toString(),
      );
      print('$from - $to');
      diffs[i] = await getTimelines(issues, type);
    }
    return diffs;
  }

  Future<List<History<T>>> getTimelines<T>(
    List<T> issues,
    UpdateType<T, T> issueType,
  ) async {
    final diffList = <History<T>>[];
    for (final issue in issues) {
      final timeline =
          await ref.getData(TimelineType(issueType), issueType.key(issue));
      if (timeline != null) {
        diffList.add(History(issueType, issue, timeline));
      }
    }
    return diffList;
  }

  DateTime getFrom(int i) =>
      DateTime(referenceDate.year, referenceDate.month - i);

  DateTime getTo(int i) =>
      DateTime(referenceDate.year, referenceDate.month - i + 1);

  List<Issue> getPIssues(int i, List<Issue> openIssues) {
    return openIssues
        .where((issue) => issue.labels.any((label) => isPLabel(i, label)))
        .toList();
  }

  List<PullRequest> getPPullRequests(int priority, List<PullRequest> openPRs) {
    return openPRs
        .where((pr) =>
            pr.labels?.any((label) => isPLabel(priority, label)) ?? false)
        .toList();
  }

  Future<List<T>> getOpen<S, T>(UpdateType<S, T> type) async =>
      await ref.getAllWith(type, orderBy: 'state', equalTo: 'open');

  bool isPLabel(int priority, IssueLabel label) {
    //TODO: Account for different types of priority labels
    return label.name == 'P$priority';
  }

  Map<RepositorySlug, (int, int)> getUntriagedRepositories(
      List<Issue> openIssues) {
    final untriagedPerRepo = <RepositorySlug, (int, int)>{};
    for (final issue in openIssues) {
      final slug = issue.repoSlug!;
      untriagedPerRepo.putIfAbsent(slug, () => (0, 0));
      // TODO: Refine this to avoid auto-labels such as `pkg:something`
      final isUntriaged = issue.labels.isEmpty;
      if (isUntriaged) {
        untriagedPerRepo.update(slug, (value) => (value.$1 + 1, value.$2 + 1));
      } else {
        untriagedPerRepo.update(slug, (value) => (value.$1, value.$2 + 1));
      }
    }
    final onlyTop = untriagedPerRepo.entries
        .sortedBy<num>((repoEntry) => repoEntry.value.$2)
        .reversed
        .take(untriagedPerRepo.length ~/ 2)
        .sortedBy<num>((repoEntry) => repoEntry.value.$1 / repoEntry.value.$2)
        .reversed
        .take(5);
    return Map.fromEntries(onlyTop);
  }
}
