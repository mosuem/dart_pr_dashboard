import 'package:github/github.dart';

extension IssueUtils on Issue {
  int get upvotes {
    return (reactions?.heart ?? 0) +
        (reactions?.plusOne ?? 0) -
        (reactions?.minusOne ?? 0);
  }

  bool authorIsGoogler(Set<String> googlers) => googlers.contains(user?.login);

  RepositorySlug? get repoSlug {
    final url = repositoryUrl;
    if (url == null) return null;

    const marker = '/repos/';
    final index = url.indexOf(marker);
    return index == -1
        ? null
        : RepositorySlug.full(url.substring(index + marker.length));
  }
}
