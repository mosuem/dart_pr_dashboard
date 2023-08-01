import 'dart:convert';

import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:github/github.dart';

sealed class UpdateType<T> {
  const UpdateType();

  Object encode();
  String? get name;
  String get url;
  String get key;
}

final class IssueType extends UpdateType<Issue> {
  final Issue issue;

  const IssueType(this.issue);

  static Issue decode(Object decoded) =>
      _decodeIssue(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode() => _encodeIssue(issue);

  @override
  String get name => 'issues';

  @override
  String get url => '$name/data';

  @override
  String get key => issue.id.toString();
}

final class PullRequestType extends UpdateType<PullRequest> {
  final PullRequest pr;

  const PullRequestType(this.pr);

  static PullRequest decode(Object decoded) =>
      _decodePR(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode() => _encodePR(pr);

  @override
  String get name => 'pullrequests';

  @override
  String get url => '$name/data';

  @override
  String get key => pr.id.toString();
}

final class TimelineType extends UpdateType<List<TimelineEvent>> {
  final List<TimelineEvent> events;

  final UpdateType parent;

  const TimelineType(this.parent, this.events);

  static List<TimelineEvent> decode(Object decoded) =>
      _decodeTimeline(decoded as List);

  @override
  List encode() => _encodeTimeline(events);

  @override
  String get name => 'timeline';

  @override
  String get url => '${parent.name}/timeline';

  @override
  String get key => parent.key;
}

final class IssueTestType extends IssueType {
  const IssueTestType(super.issue);

  static Issue decode(Object decoded) =>
      _decodeIssue(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode() => _encodeIssue(issue);

  @override
  String get name => 'testType';

  @override
  String get url => '$name/data';

  @override
  String get key => issue.id.toString();
}

final class PullRequestTestType extends PullRequestType {
  const PullRequestTestType(super.pr);

  static PullRequest decode(Object decoded) =>
      _decodePR(decoded as Map<String, dynamic>);

  @override
  Map<String, dynamic> encode() => _encodePR(pr);

  @override
  String get name => 'testType';

  @override
  String get url => '$name/data';

  @override
  String get key => pr.id.toString();
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
