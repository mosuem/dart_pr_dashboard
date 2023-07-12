import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:github/github.dart';

import 'firebase_options.dart';
import 'issue_utils.dart';
import 'pull_request_utils.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Stream<List<User>> streamGooglersFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('googlers/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as String)
      .map((value) =>
          (jsonDecode(value) as List).map((e) => User.fromJson(e)).toList());
}

Stream<List<Issue>> streamIssuesFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('issues/data/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map((reposToIssues) => reposToIssues.entries
          .map(
            (repoToIssues) => (repoToIssues.value as Map)
                .values
                .map((issueJson) => decodeIssue(issueJson))
                .toList(),
          )
          .expand((listOfIssues) => listOfIssues)
          .toList());
}

Stream<List<PullRequest>> streamPullRequestsFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('pullrequests/data/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map((reposToPRs) => reposToPRs.entries
          .map(
            (repoToPRs) => (repoToPRs.value as Map)
                .values
                .map((prJson) => decodePR(prJson))
                .toList(),
          )
          .expand((listOfPRs) => listOfPRs)
          .toList());
}
