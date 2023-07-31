import 'dart:convert';

import 'package:github/github.dart';

Issue decodeIssue(String json) {
  final Map<String, dynamic> decoded = jsonDecode(json);
  final decodedIssue = decoded['issue'] as Map<String, dynamic>;
  return Issue.fromJson(decodedIssue);
}

String encodeIssue(Issue pr) {
  return jsonEncode({'issue': pr});
}

String? getMatch(Issue issue, String columnName, List<User> googlers) {
  switch (columnName) {
    case 'title':
      return issue.title;
    default:
      return null;
  }
}

extension IssueUtils on Issue {
  int get upvotes {
    return (reactions?.heart ?? 0) +
        (reactions?.plusOne ?? 0) -
        (reactions?.minusOne ?? 0);
  }

  bool authorIsGoogler(Set<String> googlers) => googlers.contains(user?.login);

  String? get repoSlug {
    final url = repositoryUrl;
    if (url == null) return null;

    const marker = '/repos/';
    final index = url.indexOf(marker);
    return index == -1 ? null : url.substring(index + marker.length);
  }

  bool matchesFilter(String filter) {
    // title
    if (title.toLowerCase().contains(filter)) return true;

    // repo
    final slug = repoSlug;
    if (slug != null && slug.contains(filter)) return true;

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
