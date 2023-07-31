import 'dart:io';

import 'package:github/github.dart';

GitHub getGithub([String? apikey]) {
  var authentication = Authentication.anonymous();
  if (apikey != null) {
    authentication = Authentication.withToken(apikey);
  } else {
    final file = File('.env');
    if (file.existsSync()) {
      final token = file.readAsStringSync();
      authentication = Authentication.withToken(token);
    }
  }
  final github = GitHub(auth: authentication);
  return github;
}
