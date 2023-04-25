import 'package:dart_pr_dashboard/src/misc.dart';
import 'package:dart_pr_dashboard/src/table.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';

class PullRequestTable extends StatefulWidget {
  final Stream<List<PullRequest>> pullRequests;
  final List<User> googlers;

  const PullRequestTable({
    super.key,
    required this.pullRequests,
    required this.googlers,
  });

  @override
  State<PullRequestTable> createState() => _PullRequestTableState();
}

class _PullRequestTableState extends State<PullRequestTable> {
  @override
  Widget build(BuildContext context) {
    final columns = [
      FlexColumn(
        title: 'PR',
        valueFunction: (PullRequest pr) => pr.title,
        flex: 22,
      ),
      FlexColumn(
        title: 'Repo',
        valueFunction: (PullRequest pr) => pr.base?.repo?.slug().fullName,
      ),
      FlexColumn(
        title: 'Age (days)',
        valueFunction: (PullRequest pr) => pr.createdAt,
        renderer: daysSince,
        flex: 6,
        initiallySort: true,
      ),
      FlexColumn(
        title: 'Updated (days)',
        valueFunction: (PullRequest pr) => pr.updatedAt,
        renderer: daysSince,
        flex: 6,
      ),
      FlexColumn(
        title: 'Author',
        valueFunction: (PullRequest pr) {
          var text = formatUsername(pr.user, widget.googlers);
          if (pr.authorAssociation != null) {
            text = '$text\n${pr.authorAssociation!.toLowerCase()}';
          }
          return text;
        },
      ),
      FlexColumn(
        title: 'Reviewers',
        valueFunction: (PullRequest pr) => pr.requestedReviewers
            ?.map((reviewer) => formatUsername(reviewer, widget.googlers))
            .join(', '),
      ),
      FlexColumn(
        title: 'Labels',
        flex: 12,
        valueFunction: (PullRequest pr) => pr.labels,
        renderer: (value) => value.map((e) => "'${e.name}'").join(', '),
        comparator: (a, b) => a.length.compareTo(b.length),
        renderFunction: (PullRequest pr) => Wrap(
          spacing: 4,
          runSpacing: 4,
          children: (pr.labels ?? []).map(LabelWidget.new).toList(),
        ),
      ),
    ];

    return Expanded(
      child: FlexTable<PullRequest>(
        onTap: (pr) async => await launchUrl(Uri.parse(pr.htmlUrl!)),
        columns: columns,
        rowStream: widget.pullRequests,
      ),
    );
  }
}

class LabelWidget extends StatelessWidget {
  final IssueLabel label;

  const LabelWidget(
    this.label, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = Color(int.parse('FF${label.color}', radix: 16));

    return Material(
      color: chipColor,
      shape: const StadiumBorder(),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Text(
          label.name,
          style: TextStyle(
            color: isLightColor(chipColor)
                ? Colors.grey.shade900
                : Colors.grey.shade100,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

bool isLightColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.light;
