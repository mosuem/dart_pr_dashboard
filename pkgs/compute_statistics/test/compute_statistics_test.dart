import 'package:compute_statistics/statistics.dart';
import 'package:github/github.dart';
import 'package:test/test.dart';

void main() {
  test('json statistics', () {
    var fakeStatistics = Statistics(
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
      topVotedIssues: [Issue(title: 'Implement Union types now')],
      responseRatePerMonthAndPriority: {
        1: {0: Duration.zero},
        2: {0: Duration.zero, 1: Duration.zero},
      },
    );
    expect(
      Statistics.fromJson(fakeStatistics.toJson()).toJson(),
      fakeStatistics.toJson(),
    );
  });
}
