import 'dart:math';

import 'package:dart_triage_updater/data_diff.dart';
import 'package:dart_triage_updater/firebase_database.dart' as tr;
import 'package:firebase_core/firebase_core.dart';
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
    final numDays = Random().nextInt(600);
    final numDays2 = Random().nextInt(numDays);
    return Issue(
      title: 'Issue $index',
      createdAt: DateTime.now().subtract(Duration(days: numDays)),
      updatedAt: DateTime.now()
          .subtract(Duration(days: Random().nextBool() ? numDays2 : numDays)),
      user: User(login: names[index % names.length]),
    );
  });
  return Stream.fromIterable([elements]);
}

Stream<List<PullRequest>> streamPullRequestsFromFirebaseDebug() {
  final elements = List.generate(100, (index) {
    final numDays = Random().nextInt(600);
    final numDays2 = Random().nextInt(numDays);
    return PullRequest(
      title: 'Issue $index',
      createdAt: DateTime.now().subtract(Duration(days: numDays)),
      updatedAt: DateTime.now()
          .subtract(Duration(days: Random().nextBool() ? numDays2 : numDays)),
      user: User(login: names[index % names.length]),
    );
  });
  return Stream.fromIterable([elements]);
}

Stream<List<Issue>> streamIssuesFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('changes/issues/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map(
        (idsToTimestamps) => getData(
          idsToTimestamps,
          (initial, changes) =>
              DataDiff(initial, changes, Issue.fromJson).applied(),
        ),
      );
}

List<T> getData<T>(Map<String, dynamic> idsToTimestamps,
    T Function(dynamic initial, dynamic changes) fromJson) {
  return tr.DatabaseReference.extractDataFrom(idsToTimestamps, fromJson)
      .values
      .expand((list) => list)
      .toList();
}

Stream<List<PullRequest>> streamPullRequestsFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('changes/pullrequests/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map(
        (idsToTimestamps) => getData(
          idsToTimestamps,
          (initial, changes) =>
              DataDiff(initial, changes, PullRequest.fromJson).applied(),
        ),
      );
}
