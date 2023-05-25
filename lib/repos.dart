import 'package:github/github.dart';

final List<RepositorySlug> includeRepos = {
  'grpc/grpc-dart',
}.map((e) => RepositorySlug.full(e)).toList();

final List<RepositorySlug> exludeRepos = [
  'dart-lang/site-www',
  'dart-lang/sdk',
  'dart-lang/co19',
].map((e) => RepositorySlug.full(e)).toList();
