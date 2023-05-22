// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:dart_pr_dashboard/src/misc.dart';
import 'package:dart_pr_dashboard/src/pullrequest_table.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'filter.dart';
import 'firebase_options.dart';
import 'updater.dart';

late final Map<RepositorySlug, List<PullRequest>> prs;
late final List<User> googlers;

const presetFilters = [
  (name: 'Unlabeled', filter: r'labels:$^'),
  (name: 'Without reviewers', filter: r'reviewers:$^'),
  (
    name: 'Not authored by a Googler',
    filter: 'author:.*(?<!\\($gWithCircle\\))\$'
  ),
  (name: 'Not authored by a bot', filter: r'author:.*(?<!\[bot\])$'),
];

List<({String filter, String name})> filters = [];

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await readData();
  final localFilters = await loadFilters();
  filters = [...presetFilters, ...localFilters];
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      title: 'Dart PR Dashboard',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
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
      body: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
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
            Row(children: [
              ...filters
                  .map(
                    (e) => TextButton(
                      onPressed: () {
                        final text = e.filter;
                        if (controller.text.contains(text)) {
                          controller.text =
                              controller.text.replaceAll(text, '');
                        } else {
                          controller.text += ' $text';
                        }
                        controller.text = controller.text.trim();
                      },
                      child: Text(e.name),
                    ),
                  )
                  .toList(),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final filterNameController = TextEditingController();

                  final cancelButton = TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context, false),
                  );

                  final saveButton = TextButton(
                    child: const Text('Save'),
                    onPressed: () async {
                      await saveFilter((
                        name: filterNameController.text,
                        filter: controller.text,
                      ));
                      // ignore: use_build_context_synchronously
                      Navigator.pop(context, true);
                    },
                  );

                  final dialog = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Save'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Save filter as '),
                          TextField(controller: filterNameController)
                        ],
                      ),
                      actions: [cancelButton, saveButton],
                    ),
                  );

                  if (dialog ?? false) {
                    final savedFilters = await loadFilters();
                    setState(() {
                      filters = [...presetFilters, ...savedFilters];
                    });
                  }
                },
                child: const Text('Save filter'),
              ),
            ]),
            const SizedBox(height: 16),
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
