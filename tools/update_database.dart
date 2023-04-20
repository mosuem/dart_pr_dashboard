// ignore_for_file: avoid_print

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:github/github.dart';

// import 'repos.dart';

var numberPagesToFetch = 100;
Future<void> main(List<String> args) async {
  // final db = FirebaseFirestore.instance;
  // final prCollection = db.collection('pullrequests');

  // const token = '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';
  // final github = GitHub(auth: Authentication.withToken(token));

  // // final file = File('tools/repodata.json');
  // // final prs = <RepositorySlug, List<PullRequest>>{};
  // for (final slug in repos..shuffle()) {
  //   // prs[slug] = [];
  //   final i = github.rateLimitRemaining;
  //   print('Get PRs for ${slug.fullName} with $i remaining requests.');
  //   final doc = prCollection.doc(slug.fullName);
  //   doc.set(
  //     {'last_updated': DateTime.now().millisecondsSinceEpoch},
  //     SetOptions(merge: true),
  //   );

  //   await github.pullRequests
  //       .list(slug, pages: numberPagesToFetch)
  //       .forEach((pr) => doc.set(
  //             {
  //               'prs': FieldValue.arrayUnion([pr.toJson()])
  //             },
  //           ).onError((e, _) => print('Error writing PR: $e')));
  // }
  // await file.writeAsString(
  //     jsonEncode(prs.map((key, value) => MapEntry(key.fullName, value))));
}
