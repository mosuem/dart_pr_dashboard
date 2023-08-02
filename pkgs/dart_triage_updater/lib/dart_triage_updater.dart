import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dart_triage_updater/pull_request_utils.dart';
import 'package:github/github.dart';

import 'firebase_database.dart';
import 'repos.dart';
import 'update_type.dart';

class TriageUpdater {
  final GitHub github;
  final StreamSink<String> updater =
      (StreamController<String>()..stream.listen(print)).sink;
  final DatabaseReference ref;

  TriageUpdater(this.github, [AuthRequest? request])
      : ref = DatabaseReference(request);

  Future<void> updateThese(List<String> updateTypes) async {
    if (updateTypes.contains('issues')) {
      await update(updateTypes.contains('pullrequests'));
    }
    if (updateTypes.contains('googlers')) {
      await updateGooglers(github);
    }
    updater.add('Done!');
    updater.close();
  }

  Future<void> updateGooglers(GitHub github) async {
    updater.add('Fetch googlers');
    final googlersGoogle =
        await github.organizations.listUsers('google').toList();
    updater.add('Fetched ${googlersGoogle.length} googlers from "google"');
    final googlersDart =
        await github.organizations.listUsers('dart-lang').toList();
    updater.add('Fetched ${googlersDart.length} googlers from "dart-lang"');
    final googlers = (googlersGoogle + googlersDart).toSet().toList();
    updater.add('Store googlers in database');
    await ref.saveGooglers(googlers);
  }

  Future<void> update(bool getPullRequests) async {
    final lastUpdated = await ref.getLastUpdated();
    final repositories =
        github.repositories.listOrganizationRepositories('dart-lang');
    final dartLangRepos = await repositories
        .where((repository) => !repository.archived)
        .map((repository) => repository.slug())
        .where((slug) => !exludeRepos.contains(slug))
        .toList()

    dartLangRepos
        .sortBy<num>((slug) => lastUpdated[slug]?.millisecondsSinceEpoch ?? 0);
    
    final repos = [...dartLangRepos, ...includeRepos];
    for (var i = 0; i < repos.length; i++) {
      final slug = repos[i];
      try {
        updater.add(
            'Get data for ${slug.fullName} with ${github.rateLimitRemaining} '
            'remaining requests, repo $i/${repos.length}');
        await saveIssues(slug, lastUpdated[slug], getPullRequests);
        await ref.setLastUpdated(slug);
      } catch (e) {
        updater.add(e.toString());
      }
    }
  }

  Future<List<User>> getReviewers(RepositorySlug slug, PullRequest pr) async {
    final reviewers = await github.pullRequests
        .listReviews(slug, pr.number!)
        .map((prReview) => prReview.user)
        .toList();
    await wait();
    // Deduplicate reviewers
    final uniqueNames =
        reviewers.map((e) => e.login).whereType<String>().toSet();
    reviewers.retainWhere((reviewer) => uniqueNames.remove(reviewer.login));
    return reviewers;
  }

  Future<void> saveIssues(
      RepositorySlug slug, DateTime? lastUpdated, bool getPullRequests) async {
    final issues = await github.issues
        .listByRepo(
          slug,
          perPage: 5000,
          state: 'all',
          since: lastUpdated,
        )
        .toList();
    await wait();
    for (final issue in issues) {
      final issuePR = issue.pullRequest;
      if (issuePR == null) {
        await saveIssue(slug, IssueType(), issue);
      } else if (getPullRequests) {
        final prNumberStr = issuePR.htmlUrl!.split('/').last;
        final prNumber = int.parse(prNumberStr);
        final pullRequest = await github.pullRequests.get(slug, prNumber);
        await savePullRequest(slug, PullRequestType(), pullRequest);
      }
    }
  }

  Future<void> saveIssue(
      RepositorySlug slug, IssueType type, Issue issue) async {
    try {
      final timeline =
          await github.issues.listTimeline(slug, issue.number).toList();
      await wait();
      updater.add(
          '\tHandle timeline of issue ${issue.number} from ${slug.fullName} with length ${timeline.length}');
      await ref.addData(TimelineType(type), issue, timeline);
    } catch (e) {
      updater.add('\tError when getting timeline');
    }
    await ref.addData(type, issue, issue);
  }

  Future<void> savePullRequest(
      RepositorySlug slug, PullRequestType type, PullRequest pr) async {
    updater.add('\tHandle PR ${pr.number!} from ${slug.fullName}');
    try {
      final timeline =
          await github.issues.listTimeline(slug, pr.number!).toList();
      await wait();
      updater.add(
          '\tHandle timeline of PR ${pr.number!} from ${slug.fullName} with length ${timeline.length}');
      await ref.addData(TimelineType(type), pr, timeline);
    } catch (e) {
      updater.add('\tError when getting timeline');
    }
    final list = await getReviewers(slug, pr);
    pr.reviewers = list;
    await ref.addData(type, pr, pr);
  }

  Future<void> wait() async =>
      await Future.delayed(Duration(milliseconds: 400));
}
