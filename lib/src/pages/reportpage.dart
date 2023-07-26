import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:intl4x/datetime_format.dart';
import 'package:intl4x/intl4x.dart';

class ReportPage extends StatefulWidget {
  final List<Issue> issues;
  final List<PullRequest> pullrequests;
  const ReportPage({
    super.key,
    required this.issues,
    required this.pullrequests,
  });

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
    final createdIssuesPerMonth = widget.issues.groupFoldBy<int, int>(
      (element) => element.createdAt!.month,
      (previous, element) => (previous ?? 0) + 1,
    );
    final createdPRsPerMonth = widget.pullrequests.groupFoldBy<int, int>(
      (element) => element.createdAt!.month,
      (previous, element) => (previous ?? 0) + 1,
    );
    final unlabeledIssuesPerMonth = widget.issues.groupFoldBy<int, int>(
      (element) => element.createdAt!.month,
      (previous, element) => (previous ?? 0) + 1,
    );
    final unassignedPRsPerMonth = widget.pullrequests.groupFoldBy<int, int>(
      (element) => element.createdAt!.month,
      (previous, element) => (previous ?? 0) + 1,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health report'),
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Issues and pullrequests per month',
                    style: TextStyle(fontSize: 25),
                  ),
                ),
                AspectRatio(
                  aspectRatio: 1.70,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 24, 12),
                    child: LineChart(mainData([
                      createdIssuesPerMonth,
                      createdPRsPerMonth,
                    ])),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Unassigned pullrequests and unlabeled issues',
                    style: TextStyle(fontSize: 25),
                  ),
                ),
                AspectRatio(
                  aspectRatio: 1.70,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 24, 12),
                    child: LineChart(mainData([
                      unlabeledIssuesPerMonth,
                      unassignedPRsPerMonth,
                    ])),
                  ),
                ),
              ],
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
