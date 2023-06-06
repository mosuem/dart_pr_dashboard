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
import 'src/filter/filter.dart';
import 'src/pages/homepage.dart';

ValueNotifier<List<PullRequest>> pullrequests = ValueNotifier([]);
ValueNotifier<List<User>> googlers = ValueNotifier([]);

Future<void> main() async {
  runApp(MyApp(initApp: initApp));
}

Future<void> initApp(ValueNotifier<bool> darkMode) async {
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

  streamPullRequestsFromFirebase();
  streamGooglersFromFirebase();
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
      .map((value) => value.entries
          .map(
            (e) => (e.value as Map).values.map((e) => decodePR(e)).toList(),
          )
          .expand((list) => list)
          .toList())
      .forEach((prs) => pullrequests.value = prs);
}

class MyApp extends StatelessWidget {
  final ValueNotifier<bool> darkMode = ValueNotifier(true);

  final Future<void> Function(ValueNotifier<bool>) initApp;

  MyApp({required this.initApp, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initApp(darkMode),
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
                googlers: googlers,
                pullrequests: pullrequests,
              ),
              title: 'Dart PR Dashboard',
              theme: value ? ThemeData.dark() : ThemeData.light(),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}
