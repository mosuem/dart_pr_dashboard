import 'dart:convert';
import 'dart:io';

import 'package:github/github.dart';

Future<void> main(List<String> args) async {
  final github = GitHub(
      auth:
          Authentication.withToken('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'));
  final googlers = await github.organizations.listUsers('google').toList();
  final googlers2 = await github.organizations.listUsers('dart-lang').toList();
  File('tools/googlers.json')
      .writeAsStringSync(jsonEncode(Set.from(googlers + googlers2).toList()));
}
