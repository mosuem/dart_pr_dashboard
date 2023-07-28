import 'dart:convert';
import 'dart:math';

import 'package:dart_triage_updater/firebase_database.dart' as tr;
import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:github/github.dart';

import 'fake_names.dart';
import 'firebase_options.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Stream<List<User>> streamGooglersFromFirebase() {
  return Stream.value([]);
  // return FirebaseDatabase.instance
  //     .ref()
  //     .child('googlers/')
  //     .onValue
  //     .map((event) => event.snapshot)
  //     .where((snapshot) => snapshot.exists)
  //     .map((snapshot) => snapshot.value as String)
  //     .map((value) =>
  //         (jsonDecode(value) as List).map((e) => User.fromJson(e)).toList());
}

Stream<List<Issue>> streamIssuesFromFirebaseDebug() {
  final elements = List.generate(100, (index) {
    final numDays = Random().nextInt(600) + 1;
    final numDays2 = Random().nextInt(numDays);
    final issue = Issue(
      title: 'Issue $index',
      createdAt: DateTime.now().subtract(Duration(days: numDays)),
      updatedAt: DateTime.now()
          .subtract(Duration(days: Random().nextBool() ? numDays2 : numDays)),
      user: User(login: names[index % names.length]),
    );
    return issue;
  });
  return Stream.fromIterable([elements]);
}

Stream<List<PullRequest>> streamPullRequestsFromFirebaseDebug() {
  final diffs = List.generate(100, (index) {
    final numDays = Random().nextInt(600) + 1;
    final numDays2 = Random().nextInt(numDays);
    final pullRequest = PullRequest(
      title: 'Issue $index',
      createdAt: DateTime.now().subtract(Duration(days: numDays)),
      updatedAt: DateTime.now()
          .subtract(Duration(days: Random().nextBool() ? numDays2 : numDays)),
      user: User(login: names[index % names.length]),
    );
    return pullRequest;
  });
  return Stream.fromIterable([diffs]);
}

Stream<List<Issue>> streamIssuesFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('changes/issues/data/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map((data) => getData<Issue>(data, Issue.fromJson)
          .values
          .expand((issues) => issues)
          .toList());
}

Map<RepositorySlug, List<T>> getData<T>(Map<String, dynamic> idsToTimestamps,
    T Function(Map<String, dynamic> initial) fromJson) {
  return tr.DatabaseReference.extractDataFrom(idsToTimestamps, fromJson)
      .values
      .expand((list) => list)
      .toList();
}

Stream<List<PullRequest>> streamPullRequestsFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('changes/pullrequests/data/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map((data) => getData<PullRequest>(data, decodePR)
          .values
          .expand((issues) => issues)
          .toList());
}
