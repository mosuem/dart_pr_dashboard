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
}
