import 'dart:convert';

import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:github/github.dart';
import 'package:test/test.dart';

void main() {
  test('Serialize -> Deserialize PR', () {
    final pullRequest = PullRequest(commentsCount: 2);
    pullRequest.reviewers = [User(id: 5), User(id: 2)];

    final encoded = encodePR(pullRequest);
    final simulateJsonTransport = jsonDecode(jsonEncode(encoded));
    final decodedPR = decodePR(simulateJsonTransport);

    expect(decodedPR.commentsCount, equals(pullRequest.commentsCount));
    expect(decodedPR.reviewers.map((e) => e.id),
        orderedEquals(pullRequest.reviewers.map((e) => e.id)));
  });
}
