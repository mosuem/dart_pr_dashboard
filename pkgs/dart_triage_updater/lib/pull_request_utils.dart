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
}

Map<String, dynamic> encodePR(PullRequest pr) {
  return {
    'pr': pr,
    'reviewers': pr.reviewers,
  };
}

PullRequest decodePR(Map<String, dynamic> decoded) {
  final decodedPR = decoded['pr'] as Map<String, dynamic>;
  final decodedReviewers = decoded['reviewers'] as List?;
  final pr = PullRequest.fromJson(decodedPR);
  pr.reviewers = decodedReviewers?.map((e) => User.fromJson(e)).toList() ?? [];
  pr.requestedReviewers?.removeWhere((requestedReviewer) => pr.reviewers
      .any((reviewer) => reviewer.login == requestedReviewer.login));
  return pr;
}
