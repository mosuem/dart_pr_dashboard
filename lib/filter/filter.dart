import 'package:github/github.dart';

import '../pull_request_utils.dart';
import '../src/misc.dart';
import 'matcher.dart';

class SearchFilter {
  final List<User> googlers;
  final Map<String, Set<SearchMatcher>> _filterByColumn;

  SearchFilter._(this._filterByColumn, this.googlers);

  static SearchFilter? fromFilter(String source, List<User> googlers) {
    final filterByColumn = <String, Set<SearchMatcher>>{};
    final allMatches = searchPattern.allMatches(source);
    try {
      for (final match in allMatches) {
        final columnName = match[1];
        final matcher = match[2] ?? match[3];
        if (columnName == null || matcher == null) return null;
        final rangeMatch = rangePattern.matchAsPrefix(matcher);
        SearchMatcher? searchMatcher;
        if (rangeMatch != null) {
          final min = rangeMatch[1];
          final max = rangeMatch[2];
          if (min != null && max != null) {
            searchMatcher = RangeMatcher(Range(int.parse(min), int.parse(max)));
          }
        } else {
          searchMatcher = RegexMatcher(RegExp(matcher));
        }
        if (searchMatcher != null) {
          filterByColumn.putIfAbsent(columnName, () => {}).add(searchMatcher);
        }
      }
      if (allMatches.isEmpty) return null;
    } catch (e) {
      // ignore: avoid_print
      print(e);
      return null;
    }
    return SearchFilter._(filterByColumn, googlers);
  }

  String? getMatch(PullRequest pr, String columnName) {
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

  bool appliesTo(PullRequest pr) {
    return _filterByColumn.entries.every((entry) {
      final match = getMatch(pr, entry.key);
      if (match != null) {
        return entry.value.every((matcher) => matcher.hasMatch(match));
      } else {
        return true;
      }
    });
  }
}
