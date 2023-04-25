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
        flex: 20,
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
        title: 'Labels',
        valueFunction: (PullRequest pr) => pr.labels,
        renderer: (value) => value.map((e) => "'${e.name}'").join(', '),
        comparator: (a, b) => a.length.compareTo(b.length),
        renderFunction: (PullRequest pr) => Wrap(
          children: (pr.labels ?? [])
              .map((e) => Chip(
                    backgroundColor: Color(
                      int.parse('99${e.color}', radix: 16),
                    ),
                    label: Text(e.name),
                  ))
              .toList(),
        ),
      ),
      FlexColumn(
          title: 'Author',
          valueFunction: (PullRequest pr) =>
              formatUsername(pr.user, widget.googlers)),
      FlexColumn(
        title: 'Reviewers',
        valueFunction: (PullRequest pr) => pr.requestedReviewers
            ?.map(
              (reviewer) => formatUsername(
                reviewer,
                widget.googlers,
              ),
            )
            .join(', '),
      ),
      FlexColumn(
        title: 'Author association',
        valueFunction: (PullRequest pr) => pr.authorAssociation,
      ),
      // FlexColumn(
      //   title: 'State',
      //   valueFunction: (PullRequest pr) => pr.state,
      //   flex: 5,
      // ),
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
