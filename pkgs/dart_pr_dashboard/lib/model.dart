import 'dart:async';

import 'package:dart_triage_updater/diff.dart';
import 'package:flutter/foundation.dart';
import 'package:github/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase.dart';

class AppModel {
  final ValueNotifier<bool> darkMode = ValueNotifier(true);

  ValueListenable<bool> get busy => _busy;

  final ValueNotifier<bool> _busy = ValueNotifier(false);
  int _busyCount = 0;

  final ValueNotifier<List<User>> googlers = ValueNotifier([]);

  ValueNotifier<List<Issue>>? _issues;
  ValueListenable<List<Issue>> get issues {
    if (_issues == null) {
      _issues = ValueNotifier([]);
      streamIssuesFromFirebaseDebug().listen((event) {
        _strobeBusy();
        _issues!.value = event;
      });
    }

    return _issues!;
  }

  ValueNotifier<List<PullRequest>>? _pullrequests;
  ValueListenable<List<PullRequest>> get pullrequests {
    if (_pullrequests == null) {
      _pullrequests = ValueNotifier([]);
      streamPullRequestsFromFirebaseDebug().listen((event) {
        _strobeBusy();
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

      _strobeBusy();

      googlers.value = event;
    });

    await _googlersAvailable.future;
  }

  void _strobeBusy() {
    _busyCount++;
    if (_busyCount == 1) {
      _busy.value = true;
    }

    Timer(const Duration(milliseconds: 3000), () {
      _busyCount--;
      if (_busyCount == 0) {
        _busy.value = false;
      }
    });
  }
}
