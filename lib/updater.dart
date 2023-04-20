import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repos.dart';

var githubToken = 'GITHUB_TOKEN';

class UpdaterPage extends StatelessWidget {
  UpdaterPage({super.key});

  final StreamController<String> streamController = StreamController();

  @override
  Widget build(BuildContext context) {
    final c = TextEditingController();
    final c2 = TextEditingController(text: '7');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database updater'),
      ),
      body: FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const CircularProgressIndicator();
            final instance = snapshot.data!;
            c.text = instance.getString(githubToken) ?? '';
            return Center(
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Github token'),
                    TextField(controller: c),
                    const Text('Update if older than # days:'),
                    TextField(
                      controller: c2,
                      keyboardType: TextInputType.number,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () async => await fetchGooglers(
                              c.text,
                              streamController.sink,
                            ),
                            child: const Text('Fetch googlers'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await instance.setString(githubToken, c.text);
                              await update(
                                c.text,
                                int.parse(c2.text),
                                streamController.sink,
                              );
                            },
                            child: const Text('Update database'),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<String>(
                        stream: streamController.stream,
                        builder: (context, snapshot) {
                          return Text(snapshot.data ?? '');
                        }),
                  ],
                ),
              ),
            );
          }),
    );
  }
}

Future<void> update(String token, int since, StreamSink<String> sink) async {
  final github = GitHub(auth: Authentication.withToken(token));

  for (final slug in [...repos..shuffle()]) {
    try {
      final ref = FirebaseDatabase.instance
          .ref('pullrequests/last_updated/${slug.owner}:${slug.name}');
      final snapshot2 = await ref.get();
      DateTime lastUpdated;
      if (snapshot2.exists) {
        lastUpdated =
            DateTime.fromMillisecondsSinceEpoch(snapshot2.value as int);
      } else {
        lastUpdated = DateTime.fromMillisecondsSinceEpoch(0);
      }
      final daysSinceUpdate = DateTime.now().difference(lastUpdated).inDays;
      if (daysSinceUpdate > since) {
        final ref2 = FirebaseDatabase.instance
            .ref('pullrequests/data/${slug.owner}:${slug.name}');
        await ref.set(DateTime.now().millisecondsSinceEpoch);
        sink.add(
            'Get PRs for ${slug.fullName} with ${github.rateLimitRemaining} remaining requests.');
        await github.pullRequests
            .list(
              slug,
              pages: 1000,
            )
            .forEach(
                (pr) async => await addPullRequestToDatabase(ref2, pr, sink));
        sink.add('Done!');
      } else {
        sink.add(
            'Not updating ${slug.fullName} has been updated $daysSinceUpdate days ago');
      }
    } catch (e) {
      sink.add(e.toString());
    }
  }
}

Future<void> fetchGooglers(String token, StreamSink<String> sink) async {
  final ref = FirebaseDatabase.instance.ref('googlers');

  final github = GitHub(auth: Authentication.withToken(token));

  sink.add('Fetch googlers');
  final googlersGoogle =
      await github.organizations.listUsers('google').toList();
  sink.add('Fetched ${googlersGoogle.length} googlers from "google"');
  final googlersDart =
      await github.organizations.listUsers('dart-lang').toList();
  sink.add('Fetched ${googlersDart.length} googlers from "dart-lang"');
  final googlers = (googlersGoogle + googlersDart).toSet().toList();
  sink.add('Store googlers in database');
  await ref.set(jsonEncode(googlers));
  sink.add('Done!');
}

Future<void> addPullRequestToDatabase(
  DatabaseReference ref,
  PullRequest pr,
  StreamSink<String> sink,
) async {
  sink.add('Handle PR ${pr.id} from ${pr.base!.repo!.slug().fullName}');
  return await ref.child(pr.id!.toString()).set(jsonEncode(pr)).onError(
        (e, _) => throw Exception('Error writing PR: $e'),
      );
}
