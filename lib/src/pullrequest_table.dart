import 'package:dashboard_ui/ui/table.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:dart_pr_dashboard/src/misc.dart';
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
      PrColumn('repo', (pr) => pr.base?.repo?.slug().name),
      PrColumn('number', (pr) => pr.number),
      PrColumn('title', (pr) => pr.title),
      PrColumn('created_at', (pr) => pr.createdAt, daysSince),
      PrColumn('updated_at', (pr) => pr.updatedAt, daysSince),
      PrColumn(
        'labels',
        (pr) => pr.labels,
        (value) => value.map((e) => "'${e.name}'").join(', '),
        (a, b) => a.length.compareTo(b.length),
        (context, pr, out) => Wrap(
            children: (pr.labels ?? [])
                .map((e) => Chip(
                      backgroundColor: Color(
                        int.parse('99${e.color}', radix: 16),
                      ),
                      label: Text(e.name),
                    ))
                .toList()),
      ),
      PrColumn('state', (pr) => pr.state),
      PrColumn('author', (pr) => formatUsername(pr.user, widget.googlers)),
      PrColumn(
        'reviewers',
        (pr) => pr.requestedReviewers
            ?.map(
              (reviewer) => formatUsername(
                reviewer,
                widget.googlers,
              ),
            )
            .join(', '),
      ),
      PrColumn('author_association', (pr) => pr.authorAssociation),
    ];
    return Expanded(
      child: StreamBuilder<List<PullRequest>>(
          stream: widget.pullRequests,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            return VTable<PullRequest>(
              startsSorted: true,
              supportsSelection: true,
              onDoubleTap: (pr) async =>
                  await launchUrl(Uri.parse(pr.htmlUrl!)),
              columns: columns
                  .map((column) => VTableColumn<PullRequest>(
                        width: column.width,
                        grow: column.grow,
                        alignment: Alignment.centerRight,
                        label: column.title,
                        transformFunction: column.transformFunction,
                        compareFunction: column.compareFunction,
                        renderFunction: column.renderFunction,
                      ))
                  .toList(),
              items: snapshot.data!,
            );
          }),
    );
  }
}

class PrColumn<T> {
  final String title;
  final T? Function(PullRequest pr) valueFunction;
  final String Function(T value)? renderer;
  final int Function(T a, T b)? comparator;
  final Widget Function(BuildContext context, PullRequest pr, String out)?
      renderFunction;

  PrColumn(
    this.title,
    this.valueFunction, [
    this.renderer,
    this.comparator,
    this.renderFunction,
  ]);

  int get width => T is DateTime ? 10 : 200;
  double get grow => T is DateTime ? 0.1 : 0.5;

  String transformFunction(PullRequest pr) {
    final v = valueFunction(pr);
    if (v == null) return '';
    return renderer != null ? renderer!(v) : v.toString();
  }

  int compareFunction(PullRequest a, PullRequest b) {
    final va = valueFunction(a);
    final vb = valueFunction(b);
    if (va == null) return -1;
    if (vb == null) return 1;
    if (comparator != null) {
      return comparator!(va, vb);
    } else {
      return (va as Comparable).compareTo(vb);
    }
  }
}
