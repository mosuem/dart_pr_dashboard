import 'dart:math';

import 'package:collection/collection.dart';
import 'package:compute_statistics/compute_statistics.dart';
import 'package:compute_statistics/statistics.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:intl4x/datetime_format.dart';
import 'package:intl4x/intl4x.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtable/vtable.dart';

import '../issue_table.dart';

class ReportPage extends StatefulWidget {
  final ValueListenable<List<Issue>> issues;
  final ValueListenable<List<PullRequest>> pullrequests;
  final ValueListenable<Statistics?> statistics;
  final ValueListenable<List<User>> googlers;

  const ReportPage({
    super.key,
    required this.issues,
    required this.pullrequests,
    required this.statistics,
    required this.googlers,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.googlers,
      builder: (context, googlers, child) {
        return ValueListenableBuilder(
          valueListenable: widget.issues,
          builder: (context, issues, child) {
            return ValueListenableBuilder(
              valueListenable: widget.pullrequests,
              builder: (context, pullrequests, child) {
                return ValueListenableBuilder(
                  valueListenable: widget.statistics,
                  builder: (context, statistics, child) {
                    if (statistics == null) {
                      return const CircularProgressIndicator();
                    }
                    return ReportWidget(
                      issues: issues,
                      pullrequests: pullrequests,
                      statistics: statistics,
                      googlers: googlers,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class ReportWidget extends StatelessWidget {
  const ReportWidget({
    super.key,
    required this.issues,
    required this.pullrequests,
    required this.statistics,
    required this.googlers,
  });

  final List<Color> issueColors = const [
    Colors.cyan,
    Colors.blue,
  ];
  final List<Color> pullrequestColors = const [
    Colors.red,
    Colors.orange,
  ];
  final List<Issue> issues;
  final List<PullRequest> pullrequests;
  final Statistics statistics;
  final List<User> googlers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health report'),
      ),
      body: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Text(
              'Statistics as of ${Intl().datetimeFormat(const DateTimeFormatOptions(dateFormatStyle: TimeFormatStyle.medium)).format(statistics.timeStamp)}',
              style: const TextStyle(fontSize: 30),
            ),
          ),
          Column(
            children: [
              (
                'P0 Issues',
                issues
                    .where((issue) =>
                        issue.labels.any((label) => isPriorityLabel(0, label)))
                    .toList()
              ),
              (
                'P1 Issues',
                issues
                    .where((issue) =>
                        issue.labels.any((label) => isPriorityLabel(1, label)))
                    .toList()
              ),
              ('Upvoted P2 Issues', statistics.importantP2Issues),
            ]
                .map(
                  (e) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        e.$1,
                        style: const TextStyle(fontSize: 24),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: e.$2.isNotEmpty
                            ? LimitedBox(
                                maxHeight: 500,
                                child: IssueTable(
                                  issues: e.$2,
                                  googlers: googlers,
                                  showActions: false,
                                ),
                              )
                            : const Text('No issues'),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: 400,
                width: 700,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            'Time to Label per Month',
                            style: TextStyle(fontSize: 20),
                          ),
                          Text(
                            'Show the average duration it took to label an issue in that month.',
                            style: TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 24, 12),
                        child: BarChart(barData(
                            sortReversed(statistics.timeToLabelPerMonth.map(
                                (key, value) =>
                                    MapEntry(key, [value.inHours]))),
                            (p0) =>
                                formatDuration(Duration(hours: p0.round())))),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 400,
                width: 700,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            'Unlabeled Issues per Month',
                            style: TextStyle(fontSize: 20),
                          ),
                          Text(
                            'Shows the total number of issues created that month, and what number of those were closed in the same month.',
                            style: TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 24, 12),
                        child: BarChart(barData(
                            sortReversed(statistics.unlabeledIssuesPerMonth.map(
                                (key, value) =>
                                    MapEntry(key, [value.$2, value.$1]))),
                            (p0) => p0.toString())),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(
            width: 800,
            height: 400,
            child: VTable<(RepositorySlug, int, int)>(
              onDoubleTap: (data) => launchUrl(
                  Uri.parse('https://github.com/${data.$1.fullName}')),
              items: statistics.repositoriesWithMostUntriaged.entries
                  .map((e) => (e.key, e.value.$1, e.value.$2))
                  .sortedBy<num>((element) => element.$2)
                  .reversed
                  .toList(),
              columns: [
                VTableColumn(
                  label: 'Repository',
                  width: 400,
                  renderFunction: (context, object, out) =>
                      Text(object.$1.fullName),
                  compareFunction: (a, b) =>
                      a.$1.fullName.compareTo(b.$1.fullName),
                ),
                VTableColumn(
                  label: 'Untriaged issues',
                  width: 200,
                  renderFunction: (context, object, out) =>
                      Text(object.$2.toString()),
                  compareFunction: (a, b) => a.$2.compareTo(b.$2),
                ),
                VTableColumn(
                  label: 'Total issues',
                  width: 200,
                  renderFunction: (context, object, out) =>
                      Text(object.$3.toString()),
                  compareFunction: (a, b) => a.$3.compareTo(b.$3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// As the entries are saved by number of months since timestamp, and we want
  /// to show them in reversed order to be chronologically in the correct one.
  Map<Month, T> sortReversed<T>(Map<Month, T> map) =>
      Map.fromEntries(map.entries.sortedBy<num>((e) => e.key).reversed);

  BarChartData barData(
    Map<int, List<num>> data,
    String Function(num) formatter,
  ) {
    return BarChartData(
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        topTitles: const AxisTitles(),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) =>
            const FlLine(color: Colors.transparent),
        getDrawingVerticalLine: (value) =>
            const FlLine(color: Colors.transparent),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.shade900),
      ),
      minY: 0,
      maxY: data.values.fold(
            0.0,
            (previous, e) => max(previous, e.max.toDouble()),
          ) *
          1.2,
      barTouchData: BarTouchData(
        enabled: true,
        handleBuiltInTouches: false,
        touchTooltipData: BarTouchTooltipData(
          tooltipBgColor: Colors.transparent,
          tooltipMargin: 0,
          tooltipPadding: EdgeInsets.zero,
          getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
            formatter(rod.toY.round()),
            const TextStyle(fontSize: 15),
          ),
        ),
      ),
      groupsSpace: 20,
      barGroups: data.entries
          .map((e) => BarChartGroupData(
                barsSpace: 6,
                x: e.key,
                showingTooltipIndicators: [1, 0],
                barRods: e.value
                    .map((e) => BarChartRodData(
                          toY: e.toDouble(),
                          color: issueColors[0],
                          width: 15,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(3),
                            topRight: Radius.circular(3),
                          ),
                        ))
                    .toList(),
              ))
          .toList(),
    );
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );
    final monthValue = value.toInt();
    final Widget text = Text(
      Intl()
          .datetimeFormat(const DateTimeFormatOptions(month: MonthStyle.short))
          .format(
              DateTime(DateTime.now().year, DateTime.now().month - monthValue)),
      style: style,
    );
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: text,
    );
  }

  String formatDuration(Duration duration) {
    if (duration.inDays > 1) {
      return '${duration.inDays} d';
    } else if (duration.inHours > 2) {
      return '${duration.inHours} h';
    } else if (duration.inMinutes > 2) {
      return '${duration.inMinutes} min';
    }
    return '${duration.inSeconds} sec';
  }
}
