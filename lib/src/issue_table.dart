import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:intl4x/intl4x.dart';
import 'package:intl4x/number_format.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtable/vtable.dart';

import '../issue_utils.dart';
import 'filter/filter.dart';
import 'misc.dart';
import 'widgets.dart';

class IssueTable extends StatefulWidget {
  final List<Issue> issues;
  final List<User> googlers;
  final ValueNotifier<SearchFilter?> filterStream;
  late final Set<String> googlerUsers;

  IssueTable({
    super.key,
    required this.issues,
    required this.googlers,
    required this.filterStream,
  }) {
    googlerUsers =
        googlers.map((googler) => googler.login).whereType<String>().toSet();
    // sort by age initially
    issues.sort((a, b) => compareDates(b.createdAt, a.createdAt));
  }

  @override
  State<IssueTable> createState() => _IssueTableState();
}

final NumberFormat _nf = Intl().numberFormat();

class _IssueTableState extends State<IssueTable> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.filterStream,
      builder: (context, filter, child) {
        final issues = widget.issues
            .where((issue) => filter?.appliesTo(issue, getMatch) ?? true)
            .toList();

        return VTable<Issue>(
          items: issues,
          tableDescription: '${_nf.format(issues.length)} issues',
          includeCopyToClipboardAction: true,
          onDoubleTap: (issue) => launchUrl(Uri.parse(issue.htmlUrl)),
          columns: [
            VTableColumn(
              label: 'Title',
              width: 200,
              grow: 1,
              alignment: Alignment.topLeft,
              transformFunction: (issue) => issue.title,
              renderFunction: (context, Issue issue, String out) {
                return textTwoLines(out);
              },
            ),
            VTableColumn(
              label: 'Repo',
              width: 80,
              grow: 0.4,
              alignment: Alignment.topLeft,
              transformFunction: (issue) => issue.repoSlug ?? '',
            ),
            VTableColumn(
              label: 'Age (days)',
              width: 50,
              grow: 0.2,
              alignment: Alignment.topRight,
              transformFunction: (Issue issue) => daysSince(issue.createdAt),
              compareFunction: (a, b) => compareDates(b.createdAt, a.createdAt),
              validators: [oldIssueValidator],
            ),
            VTableColumn(
              label: 'Updated (days)',
              width: 50,
              grow: 0.2,
              alignment: Alignment.topRight,
              transformFunction: (Issue issue) => daysSince(issue.updatedAt),
              compareFunction: (a, b) => compareDates(b.updatedAt, a.updatedAt),
            ),
            VTableColumn(
              label: 'Author',
              width: 100,
              grow: 0.4,
              alignment: Alignment.topLeft,
              transformFunction: (Issue issue) =>
                  formatUsername(issue.user, widget.googlers),
            ),
            VTableColumn(
              label: 'Assignees',
              width: 120,
              grow: 0.7,
              alignment: Alignment.topLeft,
              renderFunction: (context, issue, out) {
                final reviewers = (issue.assignees ?? [])
                    .map(
                        (reviewer) => formatUsername(reviewer, widget.googlers))
                    .join(', ');
                // TODO: Consider using a RichText widget here.
                return ClipRect(
                  child: Wrap(
                    children: [
                      if (reviewers.isNotEmpty) Text(reviewers),
                    ],
                  ),
                );
              },
            ),
            VTableColumn(
              label: 'Labels',
              width: 120,
              grow: 0.8,
              alignment: Alignment.topLeft,
              transformFunction: (issue) =>
                  issue.labels.map((e) => "'${e.name}'").join(', '),
              renderFunction: (BuildContext context, Issue issue, String out) {
                return ClipRect(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: issue.labels.map(LabelWidget.new).toList(),
                  ),
                );
              },
            ),
            VTableColumn(
              label: 'Upvotes',
              icon: Icons.thumb_up_outlined,
              width: 50,
              grow: 0.2,
              alignment: Alignment.topRight,
              transformFunction: (issue) => issue.upvotes.toString(),
              compareFunction: (a, b) => a.upvotes.compareTo(b.upvotes),
            ),
          ],
        );
      },
    );
  }
}

ValidationResult? oldIssueValidator(Issue issue) {
  final createdAt = issue.createdAt;
  if (createdAt == null) return null;

  final days = DateTime.now().difference(createdAt).inDays;
  if (days > 365) {
    return ValidationResult.warning('Issue is objectively pretty old');
  }

  return null;
}
