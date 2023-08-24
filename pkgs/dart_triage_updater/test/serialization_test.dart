import 'dart:convert';

import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:dart_triage_updater/update_type.dart';
import 'package:github/github.dart';
import 'package:test/test.dart';

void main() {
  test('Serialize -> Deserialize PR', () {
    final pullRequest = PullRequest(commentsCount: 2);
    pullRequest.reviewers = [User(id: 5), User(id: 2)];

    final pullRequestType = PullRequestType();
    final encoded = pullRequestType.encode(pullRequest);
    final simulateJsonTransport = jsonDecode(jsonEncode(encoded));
    final decodedPR = pullRequestType.decode(simulateJsonTransport);

    expect(decodedPR.commentsCount, equals(pullRequest.commentsCount));
    expect(decodedPR.reviewers.map((e) => e.id),
        orderedEquals(pullRequest.reviewers.map((e) => e.id)));
  });
  test('Serialize -> Deserialize Issue', () {
    final issue = Issue(
      commentsCount: 2,
      createdAt: DateTime.now(),
      closedAt: DateTime.now().add(Duration(hours: 1)),
    );

    final issueType = IssueType();
    final encoded = issueType.encode(issue);
    final simulateJsonTransport = jsonDecode(jsonEncode(encoded));
    final decodedIssue = issueType.decode(simulateJsonTransport);

    expect(decodedIssue.commentsCount, equals(issue.commentsCount));
    expect(decodedIssue.createdAt!.millisecondsSinceEpoch,
        closeTo(issue.createdAt!.millisecondsSinceEpoch, 1000));
    expect(decodedIssue.closedAt!.millisecondsSinceEpoch,
        closeTo(issue.closedAt!.millisecondsSinceEpoch, 1000));
  });
  test('Serialize -> Deserialize Timeline events', () {
    final events = [
      TimelineEvent(createdAt: DateTime.now()),
      LabelEvent(createdAt: DateTime.now().add(Duration(days: 1))),
    ];

    final timelineType = TimelineType(IssueTestType());
    final encoded = timelineType.encode(events);
    final simulateJsonTransport = jsonDecode(jsonEncode(encoded));
    final decodedIssue = timelineType.decode(simulateJsonTransport);

    expect(decodedIssue.first.createdAt!.millisecondsSinceEpoch,
        closeTo(events.first.createdAt!.millisecondsSinceEpoch, 1000));
    expect(decodedIssue.last.createdAt!.millisecondsSinceEpoch,
        closeTo(events.last.createdAt!.millisecondsSinceEpoch, 1000));
  });
}
