import 'dart:io';

import 'package:compute_statistics/compute_statistics.dart';

Future<void> main(List<String> arguments) async {
  var statistics = await ComputeStatistics().compute();
  var file = File('statistics_${DateTime.now().millisecondsSinceEpoch}');
  file.createSync();
  file.writeAsStringSync(statistics.toJson());
}
