import 'dart:io';

import 'package:args/args.dart';
import 'package:compute_statistics/compute_statistics.dart';
import 'package:compute_statistics/statistics_type.dart';
import 'package:dart_triage_updater/firebase_database.dart';

Future<void> main(List<String> arguments) async {
  final argParser = ArgParser()
    ..addOption('email')
    ..addOption('password')
    ..addFlag(
      'help',
      abbr: 'h',
      defaultsTo: false,
      negatable: false,
    );
  String email;
  String password;
  try {
    final parse = argParser.parse(arguments);
    if (parse['help']) {
      print(argParser.usage);
      exit(0);
    }
    email = parse['email'] as String;
    password = parse['password'] as String;
  } catch (e) {
    print(
        'Invalid arguments "$arguments" passed.\n\n Usage: ${argParser.usage}');
    exit(1);
  }
  final authRequest = AuthRequest(
    email: email,
    password: password,
    returnSecureToken: true,
  );

  final statistics = await ComputeStatistics(DateTime.now()).compute();

  print(statistics.toReport());

  await DatabaseReference(authRequest)
      .addData(StatisticsType(), statistics, statistics);
}
