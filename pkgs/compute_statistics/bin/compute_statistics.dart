import 'dart:io';

import 'package:compute_statistics/compute_statistics.dart';

Future<void> main(List<String> arguments) async {
  final statistics = await ComputeStatistics(DateTime.now()).compute();
  final file = File('statistics_${DateTime.now().millisecondsSinceEpoch}');
  file.createSync();
  file.writeAsStringSync(statistics.toJson());
}
