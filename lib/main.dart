// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:dart_pr_dashboard/src/misc.dart';
import 'package:dart_pr_dashboard/src/pullrequest_table.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';

import 'filter.dart';
import 'firebase_options.dart';
import 'updater.dart';

late final Map<RepositorySlug, List<PullRequest>> prs;
late final List<User> googlers;

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await readData();
  runApp(const MyApp());
}

Future<void> readData() async {
  final ref = FirebaseDatabase.instance.ref();
  final snapshot = await ref.child('pullrequests/data').get();
  if (snapshot.exists) {
    final value = snapshot.value as Map<String, dynamic>;
    prs = value.map(
      (k, v) => MapEntry(
        RepositorySlug.full(k.replaceFirst(':', '/')),
        (v as Map)
            .values
            .map((e) => PullRequest.fromJson(jsonDecode(e)))
            .toList(),
      ),
    );
  } else {
    print('No data available.');
  }

  final snapshot2 = await ref.child('googlers').get();
  if (snapshot2.exists) {
    final jsonEncoded = snapshot2.value as String;
    googlers =
        (jsonDecode(jsonEncoded) as List).map((e) => User.fromJson(e)).toList();
  } else {
    print('No data available.');
  }

  // --- For local development
  // final readAsStringSync = File('tools/repodata.json').readAsStringSync();
  // final Map jsonDecoded = jsonDecode(readAsStringSync);
  // prs = jsonDecoded.map((k, v) => MapEntry(RepositorySlug.full(k),
  //     (v as List).map((e) => PullRequest.fromJson(e)).toList()));
  // googlers = [];
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      title: 'Dart PR Dashboard',
      theme: ThemeData.dark(useMaterial3: true),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var controller = TextEditingController();

  final filteredPRsController = StreamController<List<PullRequest>>.broadcast();

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      final filter = SearchFilter.fromFilter(controller.text, googlers);
      final filteredPrs = prs.values
          .expand((prList) => prList)
          .where((pr) => filter?.appliesTo(pr) ?? true)
          .toList();
      filteredPRsController.sink.add(filteredPrs);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => filteredPRsController
        .sink
        .add(prs.values.expand((prList) => prList).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart PR Dashboard'),
        actions: [
          IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => UpdaterPage(),
                  ),
                );
                filteredPRsController
                    .add(prs.values.expand((prList) => prList).toList());
              },
              icon: const Icon(Icons.settings)),
        ],
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        icon: Icon(Icons.filter_list),
                        hintText:
                            r'author_association:^CONTRIBUTOR created_at:0-50 labels:^$',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      controller: controller,
                    ),
                  ),
                  StreamBuilder<List<PullRequest>>(
                      stream: filteredPRsController.stream,
                      builder: (_, snapshot) =>
                          Text('${(snapshot.data ?? []).length} PRs'))
                ],
              ),
            ),
            Row(
              children: {
                'Unlabeled': r'labels:$^',
                'Without reviewers': r'reviewers:$^',
                'Not authored by a Googler': 'author:.*[^$gWithCircle]\$'
              }
                  .entries
                  .map(
                    (e) => TextButton(
                      onPressed: () {
                        final text = e.value;
                        if (controller.text.contains(text)) {
                          controller.text =
                              controller.text.replaceAll(text, '');
                        } else {
                          controller.text += ' $text';
                        }
                        controller.text = controller.text.trim();
                      },
                      child: Text(e.key),
                    ),
                  )
                  .toList(),
            ),
            PullRequestTable(
              pullRequests: filteredPRsController.stream,
              googlers: googlers,
            ),
          ],
        ),
      ),
    );
  }
}
