import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:github/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase.dart';

class AppModel {
  final ValueNotifier<bool> darkMode = ValueNotifier(true);

  final ValueNotifier<List<User>> googlers = ValueNotifier([]);

  ValueNotifier<List<Issue>>? _issues;
  ValueListenable<List<Issue>> get issues {
    if (_issues == null) {
      _issues = ValueNotifier([]);
      streamIssuesFromFirebase().listen((event) {
        _issues!.value = event;
      });
    }

    return _issues!;
  }

  ValueNotifier<List<PullRequest>>? _pullrequests;
  ValueListenable<List<PullRequest>> get pullrequests {
    if (_pullrequests == null) {
      _pullrequests = ValueNotifier([]);
      streamPullRequestsFromFirebase().listen((event) {
        _pullrequests!.value = event;
      });
    }

    return _pullrequests!;
  }

  final Completer<bool> _googlersAvailable = Completer<bool>();

  bool get inited => _googlersAvailable.isCompleted;

  Future<void> init() async {
    // Init the dark mode value notifier.
    final prefs = await SharedPreferences.getInstance();
    darkMode.value = prefs.getBool('darkMode') ?? true;
    darkMode.addListener(() async {
      await prefs.setBool('darkMode', darkMode.value);
    });

    // Populate information from firebase.
    await initFirebase();

    // googlers
    streamGooglersFromFirebase().listen((event) {
      if (!_googlersAvailable.isCompleted) _googlersAvailable.complete(true);

      googlers.value = event;
    });

    await _googlersAvailable.future;
  }
}
