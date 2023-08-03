import 'package:compute_statistics/statistics.dart';
import 'package:dart_triage_updater/firebase_database.dart';
import 'package:dart_triage_updater/update_type.dart';

class ComputeStatistics {
  Future<Statistics> compute() async {
    var issueType = IssueType();
    for (var i = 0; i < 12; i++) {
      var from = DateTime(DateTime.now().year, DateTime.now().month - i);
      var to = DateTime(DateTime.now().year, DateTime.now().month - i + 1);
      var issues = await DatabaseReference().getCreatedBetween(
        type: issueType,
        from: from,
        to: to,
      );
      print('$from - $to');
      for (var issue in issues) {
        var timeline =
            DatabaseReference().getTimeline(TimelineType(issueType), issue.id);
        print(timeline);
      }
    }
    var fakeStatistics = Statistics(
      timeToLabelPerMonth: {},
      unlabeledIssuesPerMonth: {},
      p0Issues: [],
      p1Issues: [],
      importantP2Issues: [],
      topVotedIssues: [],
      responseRatePerMonthAndPriority: {},
    );
    return fakeStatistics;
  }
}
