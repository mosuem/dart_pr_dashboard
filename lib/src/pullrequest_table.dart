import 'dart:async';

import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtable/vtable.dart';

import '../filter.dart';
import '../pull_request_utils.dart';
import 'misc.dart';

class PullRequestTable extends StatefulWidget {
  final List<PullRequest> pullRequests;
  final List<User> googlers;
  final ValueNotifier<List<PullRequest>> filteredPRsController;

  late final Set<String> googlerUsers;

  PullRequestTable({
    super.key,
    required this.pullRequests,
    required this.googlers,
    required Stream<SearchFilter?> filterStream,
  }) : filteredPRsController = ValueNotifier<List<PullRequest>>(pullRequests) {
    filterStream.listen((filter) => filteredPRsController.value =
        pullRequests.where((pr) => filter?.appliesTo(pr) ?? true).toList());

    googlerUsers =
        googlers.map((googler) => googler.login).whereType<String>().toSet();
  }

  @override
  State<PullRequestTable> createState() => _PullRequestTableState();
}

class _PullRequestTableState extends State<PullRequestTable> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ValueListenableBuilder(
        valueListenable: widget.filteredPRsController,
        builder: (context, pullRequests, child) {
          // sort by age initially
          pullRequests.sort((a, b) => compareDates(b.createdAt, a.createdAt));

          return VTable<PullRequest>(
            items: pullRequests,
            tableDescription: '${pullRequests.length} PRs',
            rowHeight: 64.0,
            includeCopyToClipboardAction: true,
            onDoubleTap: (pr) => launchUrl(Uri.parse(pr.htmlUrl!)),
            columns: [
              VTableColumn(
                label: 'PR',
                width: 200,
                grow: 1,
                alignment: Alignment.topLeft,
                transformFunction: (pr) => pr.titleDisplay,
                styleFunction: rowStyle,
              ),
              VTableColumn(
                label: 'Repo',
                width: 80,
                grow: 0.5,
                alignment: Alignment.topLeft,
                transformFunction: (PullRequest pr) =>
                    pr.base?.repo?.slug().fullName ?? '',
                styleFunction: rowStyle,
              ),
              VTableColumn(
                label: 'Age (days)',
                width: 50,
                grow: 0.2,
                alignment: Alignment.topRight,
                transformFunction: (PullRequest pr) => daysSince(pr.createdAt),
                styleFunction: rowStyle,
                compareFunction: (a, b) =>
                    compareDates(b.createdAt, a.createdAt),
                validators: [oldPrValidator],
              ),
              VTableColumn(
                label: 'Updated (days)',
                width: 50,
                grow: 0.2,
                alignment: Alignment.topRight,
                transformFunction: (PullRequest pr) => daysSince(pr.updatedAt),
                styleFunction: rowStyle,
                compareFunction: (a, b) =>
                    compareDates(b.updatedAt, a.updatedAt),
                validators: [probablyStaleValidator],
              ),
              VTableColumn(
                label: 'Author',
                width: 100,
                grow: 0.4,
                alignment: Alignment.topLeft,
                transformFunction: (PullRequest pr) {
                  var text = formatUsername(pr.user, widget.googlers);
                  if (pr.authorAssociationDisplay != null) {
                    text = '$text, ${pr.authorAssociationDisplay}';
                  }
                  return text;
                },
                styleFunction: rowStyle,
              ),
              VTableColumn(
                label: 'Reviewers',
                width: 120,
                grow: 0.7,
                alignment: Alignment.topLeft,
                renderFunction: (context, pr, out) {
                  var reviewers = (pr.reviewers ?? [])
                      .map((reviewer) =>
                          formatUsername(reviewer, widget.googlers))
                      .join(', ');
                  final requestedReviewers = (pr.requestedReviewers ?? [])
                      .map((reviewer) =>
                          formatUsername(reviewer, widget.googlers))
                      .join(', ');
                  if (reviewers.isNotEmpty && requestedReviewers.isNotEmpty) {
                    reviewers = '$reviewers, ';
                  }
                  // TODO: Consider using a RichText widget here.
                  return ClipRect(
                    child: Wrap(
                      children: [
                        if (reviewers.isNotEmpty)
                          Text(reviewers, style: rowStyle(pr)),
                        if (requestedReviewers.isNotEmpty)
                          Text(requestedReviewers, style: draftPrStyle),
                      ],
                    ),
                  );
                },
                styleFunction: rowStyle,
                validators: [
                  (pr) => needsReviewersValidator(widget.googlerUsers, pr),
                ],
              ),
              VTableColumn(
                label: 'Labels',
                width: 120,
                grow: 0.8,
                alignment: Alignment.topLeft,
                transformFunction: (pr) =>
                    (pr.labels ?? []).map((e) => "'${e.name}'").join(', '),
                renderFunction:
                    (BuildContext context, PullRequest pr, String out) {
                  return ClipRect(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: (pr.labels ?? []).map(LabelWidget.new).toList(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

const TextStyle draftPrStyle = TextStyle(color: Colors.grey);

TextStyle? rowStyle(PullRequest pr) {
  if (pr.draft == true) return draftPrStyle;
  if (pr.authorIsCopybara) return draftPrStyle;

  return null;
}

int compareDates(DateTime? a, DateTime? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
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

ValidationResult? needsReviewersValidator(
    Set<String> googlers, PullRequest pr) {
  if (pr.allReviewers.isEmpty && !pr.authorIsGoogler(googlers)) {
    return ValidationResult.warning('PR has no reviewer assigned');
  }

  return null;
}

ValidationResult? oldPrValidator(PullRequest pr) {
  final createdAt = pr.createdAt;
  if (createdAt == null) return null;

  final days = DateTime.now().difference(createdAt).inDays;
  if (days > 365) {
    return ValidationResult.warning('PR is objectively pretty old');
  }

  return null;
}

ValidationResult? probablyStaleValidator(PullRequest pr) {
  if (pr.allReviewers.isEmpty || pr.draft == true) return null;

  final updatedAt = pr.updatedAt;
  if (updatedAt == null) return null;

  final days = DateTime.now().difference(updatedAt).inDays;
  if (days > 30) {
    return ValidationResult.warning('PR not updated recently');
  }

  return null;
}
