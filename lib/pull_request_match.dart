import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:github/github.dart';

import 'src/misc.dart';

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
