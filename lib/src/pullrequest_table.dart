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
        title: 'repo',
        valueFunction: (PullRequest pr) => pr.base?.repo?.slug().name,
      ),
      FlexColumn(
          title: 'number',
          valueFunction: (PullRequest pr) => pr.number,
          flex: 5),
      FlexColumn(
        title: 'title',
        valueFunction: (PullRequest pr) => pr.title,
        flex: 20,
      ),
      FlexColumn(
        title: 'created_at',
        valueFunction: (PullRequest pr) => pr.createdAt,
        renderer: daysSince,
        flex: 5,
        initiallySort: true,
      ),
      FlexColumn(
        title: 'updated_at',
        valueFunction: (PullRequest pr) => pr.updatedAt,
        renderer: daysSince,
        flex: 5,
      ),
      FlexColumn(
        title: 'labels',
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
          title: 'author',
          valueFunction: (PullRequest pr) =>
              formatUsername(pr.user, widget.googlers)),
      FlexColumn(
        title: 'reviewers',
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
        title: 'author_association',
        valueFunction: (PullRequest pr) => pr.authorAssociation,
      ),
      FlexColumn(
        title: 'state',
        valueFunction: (PullRequest pr) => pr.state,
        flex: 5,
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
