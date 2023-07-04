// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pull_request_utils.dart';
import 'firebase_options.dart';
import 'issue_utils.dart';
import 'src/filter/filter.dart';
import 'src/pages/homepage.dart';
import 'table_type.dart';

final ValueNotifier<List<Issue>> issues = ValueNotifier([]);
final ValueNotifier<List<PullRequest>> pullrequests = ValueNotifier([]);
final ValueNotifier<List<User>> googlers = ValueNotifier([]);

Future<void> main() async {
  runApp(MyApp(initApp: initApp));
}

Future<void> initApp(ValueNotifier<bool> darkMode, TableType type) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Init the dark mode value notifier.
  final prefs = await SharedPreferences.getInstance();
  darkMode.value = prefs.getBool('darkMode') ?? true;
  darkMode.addListener(() async {
    await prefs.setBool('darkMode', darkMode.value);
  });

  final localFilters = await loadFilters();
  filters = [...presetFilters, ...localFilters];

  if (type == TableType.issues) streamIssuesFromFirebase();
  if (type == TableType.pullrequests) streamPullRequestsFromFirebase();
  if (type != TableType.none) streamGooglersFromFirebase();
}

Future<void> streamGooglersFromFirebase() async {
  await FirebaseDatabase.instance
      .ref()
      .child('googlers/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as String)
      .map((value) =>
          (jsonDecode(value) as List).map((e) => User.fromJson(e)).toList())
      .forEach((users) => googlers.value = users);
}

Future<void> streamPullRequestsFromFirebase() async {
  await FirebaseDatabase.instance
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
          .toList())
      .forEach((prs) => pullrequests.value = prs);
}

Future<void> streamIssuesFromFirebase() async {
  await FirebaseDatabase.instance
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
          .toList())
      .forEach((issue) => issues.value = issue);
}

class MyApp extends StatelessWidget {
  final ValueNotifier<TableType> tableType = ValueNotifier(TableType.issues);
  final ValueNotifier<bool> darkMode = ValueNotifier(true);

  final Future<void> Function(ValueNotifier<bool>, TableType type) initApp;

  MyApp({required this.initApp, super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TableType>(
      valueListenable: tableType,
      builder: (context, type, child) {
        return FutureBuilder(
          future: initApp(darkMode, type),
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error?.toString()}'));
            }

            return ValueListenableBuilder<bool>(
              valueListenable: darkMode,
              builder: (BuildContext context, bool value, _) {
                return MaterialApp(
                  home: MyHomePage(
                    darkModeSwitch: darkMode,
                    typeSwitch: tableType,
                    googlers: googlers,
                    pullrequests: pullrequests,
                    issues: issues,
                    type: type,
                  ),
                  title: 'Dart PR Dashboard',
                  theme: value ? ThemeData.dark() : ThemeData.light(),
                  debugShowCheckedModeBanner: false,
                );
              },
            );
          },
        );
      },
    );
  }
}
