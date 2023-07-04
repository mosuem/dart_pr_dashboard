import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard_type.dart';
import '../../issue_utils.dart';
import '../../pull_request_utils.dart';
import '../../repos.dart';
import '../updater.dart';

var githubToken = 'GITHUB_TOKEN';

class UpdaterPage extends StatelessWidget {
  final Updater updater;

  UpdaterPage({super.key, required this.updater});

  final StreamController<String> streamController = StreamController();

  @override
  Widget build(BuildContext context) {
    final tokenController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Database updater'),
      ),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          final instance = snapshot.data!;
          tokenController.text = instance.getString(githubToken) ?? '';

          return Center(
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Github token'),
                  TextField(controller: tokenController),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () async => await fetchGooglers(
                            tokenController.text,
                            updater,
                          ),
                          child: const Text('Fetch googlers'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await instance.setString(
                                githubToken, tokenController.text);
                          },
                          child: const Text('Save token'),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<String>(
                    stream: streamController.stream,
                    builder: (context, snapshot) {
                      return Text(snapshot.data ?? '');
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> updateStoredToken(Updater updater, DashboardType type) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(githubToken);
  if (token == null) return;
  if (type == DashboardType.pullrequests) {
    await update(
      'pullrequests',
      token,
      updater,
      saveAllPullrequests,
    );
  }
  if (type == DashboardType.issues) {
    await update(
      'issues',
      token,
      updater,
      saveAllIssues,
    );
  }
}

Future<void> update(
  String dashboardType,
  String token,
  Updater updater,
  Future<void> Function(GitHub, RepositorySlug, DatabaseReference) saveAll,
) async {
  final github = GitHub(auth: Authentication.withToken(token));

  updater.status.value = true;

  final repositories =
      github.repositories.listOrganizationRepositories('dart-lang');
  final dartLangRepos = await repositories
      .where((repository) => !repository.archived)
      .map((repository) => repository.slug())
      .where((slug) => !exludeRepos.contains(slug))
      .toList();
  for (final slug in [...dartLangRepos, ...includeRepos]) {
    try {
      final ref = FirebaseDatabase.instance
          .ref('$dashboardType/last_updated/${slug.owner}:${slug.name}');
      final lastUpdatedSnapshot = await ref.get();
      DateTime lastUpdated;
      if (lastUpdatedSnapshot.exists) {
        final value = lastUpdatedSnapshot.value as int;
        lastUpdated = DateTime.fromMillisecondsSinceEpoch(value);
      } else {
        lastUpdated = DateTime.fromMillisecondsSinceEpoch(0);
      }
      final daysSinceUpdate = DateTime.now().difference(lastUpdated).inDays;
      if (daysSinceUpdate > -1) {
        final oldRef = FirebaseDatabase.instance
            .ref('$dashboardType/data/${slug.owner}:${slug.name}');
        await ref.set(DateTime.now().millisecondsSinceEpoch);
        final status =
            'Get $dashboardType for ${slug.fullName} with ${github.rateLimitRemaining} '
            'remaining requests';
        await oldRef.remove();

        updater.set(status);

        await saveAll(github, slug, oldRef);
      } else {
        final status =
            'Not updating ${slug.fullName} has been updated $daysSinceUpdate '
            'days ago';
        updater.set(status);
      }
    } catch (e) {
      updater.set(e.toString());
    }
  }

  updater.close();
}

Future<void> saveAllPullrequests(
    GitHub github, RepositorySlug slug, DatabaseReference oldRef) async {
  await github.pullRequests.list(slug, pages: 1000).forEach((pr) async {
    final list = await getReviewers(github, slug, pr);
    pr.reviewers = list;
    await addPullRequestToDatabase(oldRef, pr);
  });
}

Future<void> saveAllIssues(
    GitHub github, RepositorySlug slug, DatabaseReference prRef) async {
  await github.issues.listByRepo(slug, perPage: 1000).forEach((pr) async {
    if (pr.pullRequest == null) await addIssueToDatabase(prRef, pr);
  });
}

Future<List<User>> getReviewers(
  GitHub github,
  RepositorySlug slug,
  PullRequest pr,
) async {
  final reviewers = await github.pullRequests
      .listReviews(slug, pr.number!)
      .map((prReview) => prReview.user)
      .toList();
  // Deduplicate reviewers
  final uniqueNames = reviewers.map((e) => e.login).whereType<String>().toSet();
  reviewers.retainWhere((reviewer) => uniqueNames.remove(reviewer.login));
  return reviewers;
}

Future<void> delete(Updater updater) async {
  updater.open('Deleting all entries');

  final ref = FirebaseDatabase.instance.ref('pullrequests');
  await ref.remove();

  updater.close();
}

Future<void> fetchGooglers(String token, Updater updater) async {
  final ref = FirebaseDatabase.instance.ref('googlers');

  final github = GitHub(auth: Authentication.withToken(token));

  updater.open('Fetch googlers');
  final googlersGoogle =
      await github.organizations.listUsers('google').toList();
  updater.set('Fetched ${googlersGoogle.length} googlers from "google"');
  final googlersDart =
      await github.organizations.listUsers('dart-lang').toList();
  updater.set('Fetched ${googlersDart.length} googlers from "dart-lang"');
  final googlers = (googlersGoogle + googlersDart).toSet().toList();
  updater.set('Store googlers in database');
  await ref.set(jsonEncode(googlers));
  updater.set('Done!');
  updater.close();
}

Future<void> addPullRequestToDatabase(
  DatabaseReference ref,
  PullRequest pr, [
  StreamSink<String>? logger,
]) async {
  logger?.add('Handle PR ${pr.id} from ${pr.base!.repo!.slug().fullName}');
  return await ref.child(pr.id!.toString()).set(encodePR(pr)).onError(
        (e, _) => throw Exception('Error writing PR: $e'),
      );
}

Future<void> addIssueToDatabase(
  DatabaseReference ref,
  Issue issue, [
  StreamSink<String>? logger,
]) async {
  logger?.add(
      'Handle Issue ${issue.id} from ${issue.repository!.slug().fullName}');
  return await ref.child(issue.id.toString()).set(encodeIssue(issue)).onError(
        (e, _) => throw Exception('Error writing PR: $e'),
      );
}
