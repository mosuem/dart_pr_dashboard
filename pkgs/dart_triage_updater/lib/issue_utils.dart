import 'package:github/github.dart';

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
}
