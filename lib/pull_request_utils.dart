import 'dart:convert';

import 'package:github/github.dart';

import 'src/misc.dart';

extension ReviewerAddition on PullRequest {
  static final _values = Expando<List<User>>();

  List<User>? get reviewers => _values[this];
  set reviewers(List<User>? r) => _values[this] = r;

  String get titleDisplay {
    return draft == true ? '$title [draft]' : title ?? '';
  }

  String? get authorAssociationDisplay {
    if (authorAssociation == null || authorAssociation == 'NONE') return null;
    return authorAssociation!.toLowerCase();
  }

  List<User> get allReviewers =>
      {...?reviewers, ...?requestedReviewers}.toList();

  bool authorIsGoogler(Set<String> googlers) => googlers.contains(user?.login);

  bool get authorIsCopybara => user?.login == 'copybara-service[bot]';
}

String encodePR(PullRequest pr) {
  final jsonEncode2 = jsonEncode({
    'pr': pr,
    'reviewers': pr.reviewers,
  });
  return jsonEncode2;
}

PullRequest decodePR(String json) {
  final Map<String, dynamic> decoded = jsonDecode(json);
  final decodedPR = decoded['pr'] as Map<String, dynamic>;
  final decodedReviewers = decoded['reviewers'] as List;
  final pr = PullRequest.fromJson(decodedPR);
  pr.reviewers = decodedReviewers.map((e) => User.fromJson(e)).toList();
  pr.requestedReviewers?.removeWhere((user) =>
      pr.reviewers?.any((reviewer) => reviewer.login == user.login) ?? false);
  return pr;
}

String? getMatch(PullRequest pr, String columnName, List<User> googlers) {
  switch (columnName) {
    case 'repo':
      return pr.base?.repo?.slug().name;
    case 'number':
      return pr.number?.toString();
    case 'title':
      return pr.title;
    case 'created_at':
      return daysSince(pr.createdAt);
    case 'updated_at':
      return daysSince(pr.updatedAt);
    case 'labels':
      return pr.labels?.map((e) => e.name).join('');
    case 'state':
      return pr.state;
    case 'author':
      return formatUsername(pr.user, googlers);
    case 'reviewers':
      return pr.allReviewers.map((reviewer) => reviewer.login).join();
    case 'author_association':
      return pr.authorAssociation;
    default:
      return null;
  }
}
