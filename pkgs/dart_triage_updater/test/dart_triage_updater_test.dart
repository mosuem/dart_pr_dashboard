import 'dart:convert';

import 'package:dart_triage_updater/dart_triage_updater.dart';
import 'package:dart_triage_updater/firebase_database.dart';
import 'package:dart_triage_updater/github.dart';
import 'package:dart_triage_updater/update_type.dart';
import 'package:github/github.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  final ref = DatabaseReference(UpdateType.testType);
  test(
    'addData',
    () async {
      final issue = Issue(
        id: 1234,
        createdAt: DateTime.now(),
      );
      final issue2 = Issue(
        id: 2345,
        createdAt: DateTime.now(),
      );
      await ref.addData(jsonEncode({issue.id.toString(): issue}), 'data');
      await ref.addData(jsonEncode({issue2.id.toString(): issue2}), 'data');
    },
    skip: true,
  );
  test(
    'addGooglers',
    () async {
      await DatabaseReference.saveGooglers(
          [User(login: 'test1'), User(login: 'test2')]);
    },
    skip: true,
  );
  test(
    'set and get last updated',
    () async {
      final repositorySlug = RepositorySlug('mosuem', 'dart_triage_updater');
      await DatabaseReference.setLastUpdated(repositorySlug);
      final dateTime = await DatabaseReference.getLastUpdated();
      expect(
        dateTime[repositorySlug]!.millisecondsSinceEpoch,
        closeTo(
            DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch,
            Duration(seconds: 1).inMilliseconds),
      );
    },
  );

  test(
    'save PR',
    () async {
      final repositorySlug = RepositorySlug('mosuem', 'dart_triage_updater');
      final pullRequest = PullRequest(
        id: 99999,
        number: 3,
      );
      await TriageUpdater(getGithub())
          .savePullRequest(repositorySlug, pullRequest, UpdateType.testType);
    },
    skip: true,
  );
  test(
    'save issues',
    () async {
      await TriageUpdater(getGithub()).saveIssues(
          RepositorySlug('mosuem', 'dart_pr_dashboard'), null, true);
    },
    skip: true,
  );

  test(
    'save issue',
    () async {
      final repositorySlug = RepositorySlug('mosuem', 'dart_pr_dashboard');
      final issue = Issue(id: 8888, number: 22);
      await TriageUpdater(getGithub())
          .saveIssue(repositorySlug, issue, UpdateType.testType);
    },
    skip: true,
  );

  test(
    'Decode data',
    () async {
      final uri =
          Uri.parse('$firebaseUrl${UpdateType.testType.name}/data.json');
      final response = await http.get(uri);
      final extractDataFrom = DatabaseReference.extractDataFrom(
          jsonDecode(response.body), Issue.fromJson);
      expect(extractDataFrom, isNotEmpty);
    },
    skip: true,
  );
}
