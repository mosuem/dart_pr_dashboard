import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:dart_triage_updater/dart_triage_updater.dart';
import 'package:dart_triage_updater/firebase_database.dart';
import 'package:dart_triage_updater/github.dart';

Future<void> main(List<String> arguments) async {
  final argParser = ArgParser()
    ..addMultiOption(
      'update',
      allowed: ['issues', 'pullrequests', 'googlers'],
      defaultsTo: ['issues', 'pullrequests', 'googlers'],
      help: 'Which types to update',
    )
    ..addOption('api-key')
    ..addOption('email')
    ..addOption('password')
    ..addFlag(
      'help',
      abbr: 'h',
      defaultsTo: false,
      negatable: false,
    );
  List<String> toUpdate;
  String? apikey;
  String email;
  String password;
  try {
    final parse = argParser.parse(arguments);
    if (parse['help']) {
      print(argParser.usage);
      exit(0);
    }
    toUpdate = parse['update'] as List<String>;
    apikey = parse['api-key'] as String?;
    email = parse['email'] as String;
    password = parse['password'] as String;
  } catch (e) {
    print(
        'Invalid arguments "$arguments" passed.\n\n Usage: ${argParser.usage}');
    exit(1);
  }
  final github = getGithub(apikey);
  final authRequest = AuthRequest(
    email: email,
    password: password,
    returnSecureToken: true,
  );
  await TriageUpdater(github, authRequest).updateThese(toUpdate);
}
