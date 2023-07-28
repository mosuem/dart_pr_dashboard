import 'dart:math';

import 'package:collection/collection.dart';
import 'package:dart_triage_updater/data_diff.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:intl4x/datetime_format.dart';
import 'package:intl4x/intl4x.dart';

class ReportPage extends StatefulWidget {
  final List<DataDiff<Issue>> issueChanges;
  final List<DataDiff<PullRequest>> pullrequestChanges;
  final List<Issue> issues;
  final List<PullRequest> pullrequests;

  ReportPage({
    super.key,
    required this.issueChanges,
    required this.pullrequestChanges,
  })  : issues = issueChanges.map((e) => e.applied()!).toList(),
        pullrequests = pullrequestChanges.map((e) => e.applied()!).toList();

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<Color> issueColors = [
    Colors.cyan,
    Colors.blue,
  ];
  List<Color> pullrequestColors = [
    Colors.red,
    Colors.orange,
  ];
  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    final createdIssuesPerMonth = widget.issues.groupFoldBy<int, int>(
      (element) => element.createdAt!.month,
      (previous, element) => (previous ?? 0) + 1,
    );
    final createdPRsPerMonth = widget.pullrequests.groupFoldBy<int, int>(
      (element) => element.createdAt!.month,
      (previous, element) => (previous ?? 0) + 1,
    );
    final unlabeledIssuesPerMonth = Map.fromEntries(List.generate(
        12,
        (index) => MapEntry(
            index + 1,
            widget.issueChanges
                .map((e) => e.applied(DateTime(currentYear, index + 1)))
                .whereType<Issue>()
                .where((element) => element.state == 'open')
                .where((element) => element.labels.isEmpty)
                .length)));

    final unassignedPRsPerMonth = Map.fromEntries(List.generate(
        12,
        (index) => MapEntry(
            index + 1,
            widget.pullrequestChanges
                .map((e) => e.applied(DateTime(currentYear, index + 1)))
                .whereType<PullRequest>()
                .where((element) => (element.labels ?? []).isEmpty)
                .length)));
    final timeToLabelPerMonth = Map.fromEntries(List.generate(12, (index) {
      final map = widget.pullrequestChanges
          .map((e) => e.getTimeUntil((pr) => (pr.labels ?? []).isNotEmpty))
          .map((e) => e ?? const Duration(days: 31))
          .toList();
      final length = map.length;
      return MapEntry(
        index + 1,
        map.fold(0.0, (prev, element) => prev + element.inDays) /
            (length > 0 ? length : 1),
      );
    }));
    print(timeToLabelPerMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health report'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                generateLineChart('Issues and pullrequests per month', [
                  createdIssuesPerMonth,
                  createdPRsPerMonth,
                ]),
                generateLineChart(
                    'Unassigned pullrequests and unlabeled issues', [
                  unlabeledIssuesPerMonth,
                  unassignedPRsPerMonth,
                ]),
              ],
            ),
            Row(
              children: [
                generateBarChart('Time',
                    timeToLabelPerMonth.map((k, v) => MapEntry(k, [v]))),
                generateLineChart(
                    'Unassigned pullrequests and unlabeled issues', [
                  unlabeledIssuesPerMonth,
                  unassignedPRsPerMonth,
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget generateLineChart(String title, List<Map<int, int>> data) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 25),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.70,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 24, 12),
              child: LineChart(mainData(data)),
            ),
          ),
        ],
      ),
    );
  }

  Widget generateBarChart(String title, Map<int, List<num>> data) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 25),
            ),
          ),
          AspectRatio(
            aspectRatio: 1.70,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 24, 12),
              child: BarChart(barData(data)),
            ),
          ),
        ],
      ),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    final monthValue = value.toInt();
    final formatter = Intl()
        .datetimeFormat(const DateTimeFormatOptions(month: MonthStyle.long));
    final text = monthValue % 3 == 1
        ? Text(
            formatter.format(DateTime(DateTime.now().year, monthValue)),
            style: style,
          )
        : Container();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: text,
    );
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 15,
      color: issueColors.first,
    );
    final scaleValue = value.toInt();
    final text =
        scaleValue % 3 == 1 ? Intl().numberFormat().format(scaleValue) : '';

    return Text(text, style: style, textAlign: TextAlign.left);
  }

  Widget rightTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 15,
      color: pullrequestColors.first,
    );
    final scaleValue = value.toInt();
    final shouldDisplay = scaleValue % 3 == 1 && meta.max != value;
    final text = shouldDisplay ? Intl().numberFormat().format(scaleValue) : '';

    return Text(text, style: style, textAlign: TextAlign.right);
  }

  BarChartData barData(Map<int, List<num>> values) {
    return BarChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 10,
        verticalInterval: 10,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Colors.grey,
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return const FlLine(
            color: Colors.grey,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            getTitlesWidget: rightTitleWidgets,
            reservedSize: 42,
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 10,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minY: 0,
      maxY: values.values.fold(
            0.0,
            (previous, e) => max(previous, e.max.toDouble()),
          ) *
          1.1,
      barGroups: values.entries
          .map((e) => BarChartGroupData(
                barsSpace: 4,
                x: e.key,
                barRods: e.value
                    .map((e) => BarChartRodData(
                          toY: e.toDouble(),
                          color: issueColors[0],
                          width: 3,
                        ))
                    .toList(),
              ))
          .toList(),
    );
  }

  LineChartData mainData(List<Map<int, int>> values) {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Colors.grey,
            strokeWidth: 1,
          );
        },
        getDrawingVerticalLine: (value) {
          return const FlLine(
            color: Colors.grey,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: rightTitleWidgets,
            reservedSize: 42,
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: const Color(0xff37434d)),
      ),
      minX: 1,
      maxX: 12,
      minY: 0,
      maxY: values.fold(
            0,
            (previousValue, element) => max(previousValue, element.values.max),
          ) *
          1.1,
      lineBarsData: values
          .map((e) => LineChartBarData(
                spots: dataToFlSpot(e),
                isCurved: true,
                gradient: LinearGradient(
                  colors: issueColors,
                ),
                barWidth: 5,
                isStrokeCapRound: true,
                dotData: const FlDotData(
                  show: false,
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: issueColors
                        .map((color) => color.withOpacity(0.3))
                        .toList(),
                  ),
                ),
              ))
          .toList(),
    );
  }

  List<FlSpot> dataToFlSpot(Map<int, int> data) {
    return data.entries
        .sorted((a, b) => a.key.compareTo(b.key))
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();
  }
}
