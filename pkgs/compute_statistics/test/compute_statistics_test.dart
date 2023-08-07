import 'package:compute_statistics/statistics.dart';
import 'package:dart_triage_updater/firebase_database.dart';
import 'package:dart_triage_updater/update_type.dart';
import 'package:github/github.dart';
import 'package:test/test.dart';

void main() {
  test('json statistics', () {
    final fakeStatistics = Statistics(
      timeToLabelPerMonth: {1: Duration(hours: 1)},
      unlabeledIssuesPerMonth: {1: (5, 10)},
      p0Issues: [
        Issue(labels: [IssueLabel(name: 'P0')])
      ],
      p1Issues: [
        Issue(labels: [IssueLabel(name: 'P1')])
      ],
      importantP2Issues: [
        Issue(labels: [IssueLabel(name: 'P2')])
      ],
      p0PullRequests: [PullRequest(title: 'test')],
      p1PullRequests: [PullRequest(title: 'test2')],
      topVotedIssues: [Issue(title: 'Implement Union types now')],
      updateFrequencyPerMonthAndPriority: {
        1: {0: Duration.zero},
        2: {0: Duration.zero, 1: Duration.zero},
      },
      repositoriesWithMostUntriaged: {
        RepositorySlug('mosuem', 'dart_pr_dashboard'): (4, 30)
      },
    );
    expect(
      Statistics.fromJson(fakeStatistics.toJson()).toJson(),
      fakeStatistics.toJson(),
    );
  });

  test('Created between', () async {
    final issues = await DatabaseReference().getAllWith(
      IssueType(),
      orderBy: 'created_at',
      startAt: DateTime(2012, 9).millisecondsSinceEpoch.toString(),
      endAt: DateTime(2012, 10).millisecondsSinceEpoch.toString(),
    );
    expect(issues.length, 1);
  });
}
