import 'package:dart_triage_updater/issue_utils.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:intl4x/intl4x.dart';
import 'package:intl4x/number_format.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtable/vtable.dart';

import 'misc.dart';
import 'theme.dart';
import 'widgets.dart';

class IssueTable extends StatefulWidget {
  final List<Issue> issues;
  final List<User> googlers;

  final List<String> priorities = ['P0', 'P1', 'P2', 'P3', 'P4'];
  final List<String> types = ['type-bug', 'type-enhancement'];
  final bool showActions;

  IssueTable({
    super.key,
    required this.issues,
    required this.googlers,
    this.showActions = true,
  }) {
    // sort by age initially
    issues.sort((a, b) => compareDates(b.createdAt, a.createdAt));
  }

  @override
  State<IssueTable> createState() => _IssueTableState();
}

final NumberFormat _nf = Intl().numberFormat();

class _IssueTableState extends State<IssueTable> {
  final Set<String> priorities = {};
  final Set<String> types = {};
  String? filterText;

  void _updateFilter(String filter) {
    filter = filter.trim().toLowerCase();

    setState(() {
      filterText = filter.isEmpty ? null : filter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      SearchField(
        hintText: 'Filter',
        height: toolbarHeight,
        onChanged: (value) {
          _updateFilter(value);
        },
      ),
      const SizedBox(width: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: toolbarHeight),
        child: ToggleButtons(
          borderRadius: BorderRadius.circular(6),
          textStyle: Theme.of(context).textTheme.titleMedium,
          isSelected: [
            ...widget.priorities.map((p) => priorities.contains(p)),
          ],
          onPressed: (index) {
            setState(() {
              final label = widget.priorities[index];
              priorities.toggle(label);
            });
          },
          children: [
            ...widget.priorities.map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(p),
              );
            }),
          ],
        ),
      ),
      const SizedBox(width: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: toolbarHeight),
        child: ToggleButtons(
          borderRadius: BorderRadius.circular(6),
          textStyle: Theme.of(context).textTheme.titleMedium,
          isSelected: [
            ...widget.types.map((p) => types.contains(p)),
          ],
          onPressed: (index) {
            setState(() {
              final label = widget.types[index];
              types.toggleExclusive(label);
            });
          },
          children: [
            ...widget.types.map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(p),
              );
            }),
          ],
        ),
      ),
      const SizedBox(width: 10),
    ];

    final issues = _filterIssues(widget.issues);

    return VTable<Issue>(
      items: issues,
      tableDescription: '${_nf.format(issues.length)} issues',
      actions: widget.showActions ? actions : [],
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
          transformFunction: (issue) => issue.repoSlug?.fullName ?? '',
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
                .map((reviewer) => formatUsername(reviewer, widget.googlers))
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
  }

  List<Issue> _filterIssues(List<Issue> issues) {
    Iterable<Issue> result = issues;

    if (filterText != null) {
      result = result.where((p) => p.matchesFilter(filterText!));
    }

    if (priorities.isNotEmpty || types.isNotEmpty) {
      result = result.where((issue) {
        final labels = issue.labels.map((l) => l.name).toSet();

        if (priorities.isNotEmpty) {
          if (labels.intersection(priorities).isEmpty) return false;
        }

        if (types.isNotEmpty) {
          if (labels.intersection(types).isEmpty) return false;
        }

        return true;
      });
    }

    return result.toList();
  }
}

extension on Issue {
  bool matchesFilter(String filter) {
    // title
    if (title.toLowerCase().contains(filter)) return true;

    // repo
    final slug = repoSlug;
    if (slug != null && slug.fullName.contains(filter)) return true;

    // author
    final login = user?.login?.toLowerCase();
    if (login != null && login.contains(filter)) return true;

    // assignees
    if (assignees != null) {
      for (final assignee in assignees!) {
        final login = assignee.login?.toLowerCase();
        if (login != null && login.contains(filter)) return true;
      }
    }

    // labels
    for (final label in labels) {
      if (label.name.toLowerCase().contains(filter)) return true;
    }

    return false;
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
