import 'dart:convert';

import 'package:github/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool appliesTo<T>(T pr, String? Function(T, String, List<User>) getMatch) {
    return _filterByColumn.entries.every((entry) {
      final match = getMatch(pr, entry.key, googlers);
      if (match != null) {
        return entry.value.every((matcher) => matcher.hasMatch(match));
      } else {
        return true;
      }
    });
  }
}

Future<List<({String name, String filter})>> loadFilters() async {
  final instance = await SharedPreferences.getInstance();
  final List filters = json.decode(instance.getString('filters') ?? '[]');
  return filters
      .map((e) => (name: e['name'] as String, filter: e['filter'] as String))
      .toList();
}

Future<void> saveFilter(({String name, String filter}) namedFilter) async {
  final savedFilters = await loadFilters();
  savedFilters.removeWhere((filter) => filter.name == namedFilter.name);
  if (namedFilter.filter.isNotEmpty) savedFilters.add(namedFilter);
  final instance = await SharedPreferences.getInstance();
  final encodedFilters = json.encode(
      savedFilters.map((e) => {'name': e.name, 'filter': e.filter}).toList());
  await instance.setString('filters', encodedFilters);
}
