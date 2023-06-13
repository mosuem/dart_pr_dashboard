abstract class SearchMatcher {
  bool hasMatch(String match);
}

class RegexMatcher extends SearchMatcher {
  final RegExp matcher;

  RegexMatcher(this.matcher);

  @override
  bool hasMatch(String match) => matcher.hasMatch(match);
}

class RangeMatcher extends SearchMatcher {
  final Range range;

  RangeMatcher(this.range);

  @override
  bool hasMatch(String match) => range.contains(int.parse(match));
}

class Range {
  final int min;
  final int max;

  Range(this.min, this.max);

  bool contains(int parse) => min <= parse && parse <= max;
}

final searchPattern = RegExp(r"([^\s:]+):(?:'(.+?)'|(([^'][^\s]*)))\s?");
final rangePattern = RegExp(r'(\d+)-(\d+)');
