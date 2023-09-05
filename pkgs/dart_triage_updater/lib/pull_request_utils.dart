import 'package:github/github.dart';

extension ReviewerAddition on PullRequest {
  static final _values = Expando<List<User>>();

  List<User> get reviewers => _values[this] ?? [];
  set reviewers(List<User> r) => _values[this] = r;

  String get titleDisplay {
    return draft == true ? '$title [draft]' : title ?? '';
  }

  String? get authorAssociationDisplay {
    if (authorAssociation == null || authorAssociation == 'NONE') return null;
    return authorAssociation!.toLowerCase();
  }

  List<User> get allReviewers =>
      {...reviewers, ...?requestedReviewers}.toList();

  bool authorIsGoogler(Set<String> googlers) => googlers.contains(user?.login);

  bool get authorIsCopybara => user?.login == 'copybara-service[bot]';

  RepositorySlug? get repoSlug {
    final url = htmlUrl;
    if (url == null) return null;

    final pathParts = Uri.parse(url).pathSegments;
    return RepositorySlug(pathParts[0], pathParts[1]);
  }
}
