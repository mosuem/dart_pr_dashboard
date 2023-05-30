import 'package:dart_pr_dashboard/src/misc.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vtable/vtable.dart';

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
    return Expanded(
      child: StreamBuilder(
        stream: widget.pullRequests,
        builder:
            (BuildContext context, AsyncSnapshot<List<PullRequest>> snapshot) {
          final rows = snapshot.data ?? [];

          // sort by age initially
          rows.sort((a, b) => compareDates(b.createdAt, a.createdAt));

          return VTable<PullRequest>(
            items: rows,
            tableDescription: '${rows.length} PRs',
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
              ),
              VTableColumn(
                label: 'Author',
                width: 100,
                grow: 0.5,
                transformFunction: (PullRequest pr) {
                  var text = formatUsername(pr.user, widget.googlers);
                  if (pr.authorAssociationDisplay != null) {
                    text = '$text\n${pr.authorAssociationDisplay}';
                  }
                  return text;
                },
                styleFunction: rowStyle,
              ),
              VTableColumn(
                label: 'Reviewers',
                width: 100,
                grow: 0.5,
                transformFunction: (PullRequest pr) {
                  return (pr.requestedReviewers ?? [])
                      .map((reviewer) =>
                          formatUsername(reviewer, widget.googlers))
                      .join(', ');
                },
                styleFunction: rowStyle,
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
  return pr.draft == true ? draftPrStyle : null;
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
