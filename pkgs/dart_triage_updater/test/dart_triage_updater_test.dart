import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:dart_triage_updater/dart_triage_updater.dart';
import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:dart_triage_updater/firebase_database.dart';
import 'package:dart_triage_updater/github.dart';
import 'package:dart_triage_updater/update_type.dart';
import 'package:github/github.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

// import '../local_test/pullsvsissues.dart';

void main() {
  /// To run tests, set an authrequest for write access to the database.
  AuthRequest? authRequest;

  final ref = DatabaseReference(authRequest);
  test(
    'addData',
    () async {
      final issue = Issue(
        id: 1234,
        createdAt: DateTime.now(),
      );
      final user2 = User(login: 'testlogin', avatarUrl: 'avatarUrl');
      final issue2 = Issue(id: 2345, createdAt: DateTime.now(), user: user2);
      final events = [
        CommentEvent(
          createdAt: DateTime.now(),
          actor: user2,
          body: 'longbody',
        )
      ];

      await ref.addData(IssueTestType(), issue, issue);
      await ref.addData(IssueTestType(), issue2, issue2);
      await ref.addData(TimelineType(IssueTestType()), issue, events);
    },
    skip: true,
  );

  test(
    'Decode data',
    () async {
      final uri = Uri.parse('${firebaseUrl}testType/data.json');
      final response = await http.get(uri);
      final extractDataFrom = DatabaseReference.extractDataFrom(
          jsonDecode(response.body), IssueType());
      expect(extractDataFrom, isNotEmpty);
    },
    skip: true,
  );

  test(
    'addGooglers',
    () async {
      await ref.saveGooglers([User(login: 'test1'), User(login: 'test2')]);
    },
    skip: true,
  );

  test('Sorting repos', () {
    final list = [
      RepositorySlug('mosuem', 'dart_pr_dashboard'),
      RepositorySlug('mosuem', 'dart_triage_updater'),
    ];

    final lastUpdated = {
      RepositorySlug('mosuem', 'dart_pr_dashboard'): DateTime.now()
    };
    final sortedList = List.from(list);
    sortedList
        .sortBy<num>((slug) => lastUpdated[slug]?.millisecondsSinceEpoch ?? 0);
    expect(sortedList, orderedEquals(list.reversed.toList()));
  });

  test(
    'set and get last updated',
    () async {
      final repositorySlug = RepositorySlug('mosuem', 'dart_triage_updater');
      await ref.setLastUpdated(repositorySlug);
      final dateTime = await ref.getLastUpdated();
      expect(
        dateTime[repositorySlug]!.millisecondsSinceEpoch,
        closeTo(
            DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch,
            Duration(seconds: 1).inMilliseconds),
      );
    },
    skip: true,
  );

  test(
    'save PR',
    () async {
      final repositorySlug = RepositorySlug('mosuem', 'dart_triage_updater');
      final user2 = User(avatarUrl: 'someUrl', login: 'somelogin');
      final pullRequest = PullRequest(
        id: 99999,
        number: 3,
        user: user2,
        labels: [
          IssueLabel(
            name: 'testname',
            description: 'verylongdesc',
          )
        ],
        base: PullRequestHead(
            user: user2,
            repo: Repository(
              name: 'test',
              url: 'testurl',
              owner: UserInformation('login', 1234, 'avatarUrl', 'htmlUrl'),
            )),
        head: PullRequestHead(user: user2),
      );
      await TriageUpdater(getGithub())
          .savePullRequest(repositorySlug, PullRequestTestType(), pullRequest);
    },
    // skip: true,
  );

  test('get PR', () async {
    final map = await DatabaseReference().getData(PullRequestTestType(), 99999);
    expect(map!.reviewers, isNotEmpty);
  });
  test('get Issues', () async {
    final map = await DatabaseReference().getData(IssueTestType(), 2345);
    expect(map!.user, isNotNull);
  });
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
          .saveIssue(repositorySlug, IssueTestType(), issue);
    },
    skip: true,
  );
}
