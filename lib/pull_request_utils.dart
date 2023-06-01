import 'dart:convert';

import 'package:github/github.dart';

extension ReviewerAddition on PullRequest {
  static final _values = Expando<List<User>>();

  List<User>? get reviewers => _values[this];
  set reviewers(List<User>? r) => _values[this] = r;
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
  return pr;
}
