import 'package:compute_statistics/statistics.dart';
import 'package:dart_triage_updater/firebase_database.dart' as tr;
import 'package:dart_triage_updater/update_type.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:github/github.dart';

import 'firebase_options.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Stream<Statistics> getCurrentStatistics() {
  return FirebaseDatabase.instance
      .ref('statistics')
      .orderByKey()
      .limitToLast(1)
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value)
      .map((event) => event as Map<String, dynamic>)
      .map((event) => Statistics.fromJson(event.entries.first.value));
}

Stream<List<User>> streamGooglersFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('googlers/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as List)
      .map((value) => value.map((e) => User.fromJson(e)).toList());
}

Stream<List<Issue>> streamIssuesFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('issues/data/')
      .orderByChild('state')
      .equalTo('open')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map((reposToIssues) => tr.DatabaseReference.extractDataFrom(
          reposToIssues, const IssueType()));
}

Stream<List<PullRequest>> streamPullRequestsFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('pullrequests/data/')
      .orderByChild('state')
      .equalTo('open')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map((reposToIssues) => tr.DatabaseReference.extractDataFrom(
          reposToIssues, const PullRequestType()));
}
