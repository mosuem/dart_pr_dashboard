import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:compute_statistics/compute_statistics.dart';
import 'package:compute_statistics/statistics.dart';
import 'package:dart_triage_updater/firebase_database.dart';
import 'package:dart_triage_updater/update_type.dart';

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
  final timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
  final file = File('statistics_$timeStamp');
  file.createSync();
  file.writeAsStringSync(jsonEncode(statistics));

  await DatabaseReference(authRequest)
      .addData(StatisticsType(), statistics, statistics);
}

class StatisticsType implements UpdateType<Statistics, Statistics> {
  @override
  DateTime createdAt(Statistics data) => data.timeStamp;

  @override
  Statistics decode(Object decoded) =>
      Statistics.fromJson(decoded as Map<String, dynamic>);

  @override
  Object encode(Statistics data) => jsonDecode(jsonEncode(data));

  @override
  String key(Statistics data) =>
      data.timeStamp.millisecondsSinceEpoch.toString();

  @override
  String get name => 'statistics';

  @override
  String get url => 'statistics';
}
