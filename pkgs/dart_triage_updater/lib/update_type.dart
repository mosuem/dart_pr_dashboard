import 'dart:convert';

import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:github/github.dart';

sealed class UpdateType<S, T> {
  const UpdateType();

  Object encode(T data);
  T decode(Object decoded);
  String get url;
  String get name;
  String key(S data);
}

final class IssueType extends UpdateType<Issue, Issue> {
  const IssueType();

  @override
  Issue decode(Object decoded) => _decodeIssue(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode(Issue data) => _encodeIssue(data);

  @override
  String get name => 'issues';

  @override
  String get url => '$name/data';

  @override
  String key(Issue data) => data.id.toString();
}

final class PullRequestType extends UpdateType<PullRequest, PullRequest> {
  const PullRequestType();

  @override
  PullRequest decode(Object decoded) =>
      _decodePR(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode(PullRequest data) => _encodePR(data);

  @override
  String get name => 'pullrequests';

  @override
  String get url => '$name/data';

  @override
  String key(PullRequest data) => data.id.toString();
}

final class TimelineType<S, T> extends UpdateType<S, List<TimelineEvent>> {
  final UpdateType<S, T> parent;

  const TimelineType(this.parent);

  @override
  List<TimelineEvent> decode(Object decoded) =>
      _decodeTimeline(decoded as List);

  @override
  List encode(List<TimelineEvent> data) => _encodeTimeline(data);

  @override
  String get name => 'timeline';

  @override
  String get url {
    return '${parent.name}/timeline';
  }

  @override
  String key(S data) => parent.key(data);
}

final class IssueTestType extends IssueType {
  const IssueTestType();

  @override
  Issue decode(Object decoded) => _decodeIssue(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode(Issue data) => _encodeIssue(data);

  @override
  String get name => 'testType';

  @override
  String get url => '$name/data';

  @override
  String key(Issue data) => data.id.toString();
}

final class PullRequestTestType extends PullRequestType {
  const PullRequestTestType();

  @override
  PullRequest decode(Object decoded) =>
      _decodePR(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode(PullRequest data) => _encodePR(data);

  @override
  String get name => 'testType';

  @override
  String get url => '$name/data';

  @override
  String key(PullRequest data) => data.id.toString();
}

Map<String, dynamic> _encodePR(PullRequest pr) {
  final map = jsonDecode(jsonEncode(pr));
  map['reviewers'] = pr.reviewers;
  return map;
}

PullRequest _decodePR(Map<String, dynamic> decoded) {
  final decodedReviewers = decoded['reviewers'] as List?;
  final pr = PullRequest.fromJson(decoded);
  pr.reviewers = decodedReviewers?.map((e) => User.fromJson(e)).toList() ?? [];
  pr.requestedReviewers?.removeWhere((requestedReviewer) => pr.reviewers
      .any((reviewer) => reviewer.login == requestedReviewer.login));
  return pr;
}

List _encodeTimeline(List<TimelineEvent> timelineEvent) {
  return timelineEvent.map((e) {
    final map = jsonDecode(jsonEncode(e));
    map['created_at'] = e.createdAt?.millisecondsSinceEpoch;
    return map;
  }).toList();
}

List<TimelineEvent> _decodeTimeline(List decoded) {
  return decoded.map((e) {
    final map = e as Map<String, dynamic>;
    if (map['created_at'] != null) {
      map['created_at'] = DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          .toIso8601String();
    }
    return TimelineEvent.fromJson(map);
  }).toList();
}

Issue _decodeIssue(Map<String, dynamic> decoded) {
  if (decoded['created_at'] != null) {
    decoded['created_at'] =
        DateTime.fromMillisecondsSinceEpoch(decoded['created_at'])
            .toIso8601String();
  }
  if (decoded['closed_at'] != null) {
    decoded['closed_at'] =
        DateTime.fromMillisecondsSinceEpoch(decoded['closed_at'])
            .toIso8601String();
  }
  if (decoded['updated_at'] != null) {
    decoded['updated_at'] =
        DateTime.fromMillisecondsSinceEpoch(decoded['updated_at'])
            .toIso8601String();
  }
  return Issue.fromJson(decoded);
}

Map<String, dynamic> _encodeIssue(Issue issue) {
  final map = jsonDecode(jsonEncode(issue));
  map['created_at'] = issue.createdAt?.millisecondsSinceEpoch;
  map['closed_at'] = issue.closedAt?.millisecondsSinceEpoch;
  map['updated_at'] = issue.updatedAt?.millisecondsSinceEpoch;
  return map;
}
