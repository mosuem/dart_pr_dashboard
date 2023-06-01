import 'dart:async';

import 'package:dart_pr_dashboard/filter.dart';
import 'package:dart_pr_dashboard/pull_request_utils.dart';
import 'package:dart_pr_dashboard/src/misc.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtable/vtable.dart';

class PullRequestTable extends StatefulWidget {
  final List<PullRequest> pullRequests;
  final List<User> googlers;
  final ValueNotifier<List<PullRequest>> filteredPRsController;

  PullRequestTable({
    super.key,
    required this.pullRequests,
    required this.googlers,
    required Stream<SearchFilter?> filterStream,
  }) : filteredPRsController = ValueNotifier<List<PullRequest>>(pullRequests) {
    filterStream.listen((filter) => filteredPRsController.value =
        pullRequests.where((pr) => filter?.appliesTo(pr) ?? true).toList());
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
            rowHeight: 48.0,
            includeCopyToClipboardAction: true,
            onDoubleTap: (pr) => launchUrl(Uri.parse(pr.htmlUrl!)),
            columns: [
              VTableColumn(
                label: 'PR',
                width: 200,
                grow: 1,
                transformFunction: (pr) => pr.titleDisplay,
                styleFunction: rowStyle,
              ),
              VTableColumn(
                label: 'Repo',
                width: 80,
                grow: 0.5,
                transformFunction: (PullRequest pr) =>
                    pr.base?.repo?.slug().fullName ?? '',
                styleFunction: rowStyle,
              ),
              VTableColumn(
                label: 'Age (days)',
                width: 50,
                grow: 0.2,
                alignment: Alignment.centerRight,
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
                alignment: Alignment.centerRight,
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
                width: 110,
                grow: 0.6,
                renderFunction: (context, pr, out) {
                  final reviewers = (pr.reviewers ?? [])
                      .map((reviewer) =>
                          formatUsername(reviewer, widget.googlers))
                      .join(', ');
                  final requestedReviewers = (pr.requestedReviewers ?? [])
                      .map((reviewer) =>
                          formatUsername(reviewer, widget.googlers))
                      .join(', ');
                  return Wrap(
                    children: [
                      Text(reviewers, style: rowStyle(pr)),
                      if (reviewers.isNotEmpty) const SizedBox(width: 5),
                      Text(requestedReviewers, style: draftPrStyle),
                    ],
                  );
                },
                styleFunction: rowStyle,
                validators: [
                  (pr) => needsReviewersValidator(widget.googlers, pr),
                ],
              ),
              VTableColumn(
                label: 'Labels',
                width: 120,
                grow: 0.8,
                transformFunction: (pr) =>
                    (pr.labels ?? []).map((e) => "'${e.name}'").join(', '),
                renderFunction:
                    (BuildContext context, PullRequest pr, String out) => Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: (pr.labels ?? []).map(LabelWidget.new).toList(),
                ),
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
  if (pr.copybaraPR) return draftPrStyle;

  return null;
}

int compareDates(DateTime? a, DateTime? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

extension PullRequestExtension on PullRequest {
  String get titleDisplay {
    return draft == true ? '$title [draft]' : title ?? '';
  }

  String? get authorAssociationDisplay {
    if (authorAssociation == null || authorAssociation == 'NONE') return null;
    return authorAssociation!.toLowerCase();
  }

  List<User> get allReviewers =>
      {...?reviewers, ...?requestedReviewers}.toList();

  bool authorIsGoogler(List<User> googlers) {
    final login = user?.login;
    if (login == null) return false;

    // TODO: cache the googler logins in a set
    return googlers.any((googler) => googler.login == login);
  }

  bool get copybaraPR => user?.login == 'copybara-service[bot]';
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

ValidationResult? needsReviewersValidator(List<User> googlers, PullRequest pr) {
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
