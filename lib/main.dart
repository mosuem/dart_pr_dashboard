// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'filter.dart';
import 'firebase_options.dart';
import 'pull_request_utils.dart';
import 'src/misc.dart';
import 'src/pullrequest_table.dart';
import 'updater.dart';

final ValueNotifier<bool> updating = ValueNotifier(false);
final ValueNotifier<String?> updatingStatus = ValueNotifier(null);

final ValueNotifier<bool> darkMode = ValueNotifier(true);

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
  final Future<void> ready = () async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Init the dark mode value notifier.
    final prefs = await SharedPreferences.getInstance();
    darkMode.value = prefs.getBool('darkMode') ?? true;
    darkMode.addListener(() async {
      await prefs.setBool('darkMode', darkMode.value);
    });

    final localFilters = await loadFilters();
    filters = [...presetFilters, ...localFilters];
  }();

  runApp(MyApp(ready: ready));
}

Stream<List<User>> streamGooglersFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('googlers/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as String)
      .map((value) =>
          (jsonDecode(value) as List).map((e) => User.fromJson(e)).toList());
}

Stream<List<PullRequest>> streamPullRequestsFromFirebase() {
  return FirebaseDatabase.instance
      .ref()
      .child('pullrequests/data/')
      .onValue
      .map((event) => event.snapshot)
      .where((snapshot) => snapshot.exists)
      .map((snapshot) => snapshot.value as Map<String, dynamic>)
      .map((value) => value.entries
          .map(
            (e) => (e.value as Map).values.map((e) => decodePR(e)).toList(),
          )
          .expand((list) => list)
          .toList());
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
  final Future<void> ready;

  const MyApp({required this.ready, super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ready,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error?.toString()}'));
        }

        return ValueListenableBuilder<bool>(
          valueListenable: darkMode,
          builder: (BuildContext context, bool value, _) {
            return MaterialApp(
              home: const MyHomePage(),
              title: 'Dart PR Dashboard',
              theme: value ? ThemeData.dark() : ThemeData.light(),
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
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

  final googlersController = ValueNotifier<List<User>>([]);
  final filterStream = StreamController<SearchFilter?>();

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      final filter =
          SearchFilter.fromFilter(controller.text, googlersController.value);
      filterStream.sink.add(filter);
    });
  }

  @override
  Widget build(BuildContext context) {
    print('BUILDING HOMEPAGE');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart PR Dashboard'),
        actions: [
          SizedBox.square(
            dimension: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: updating,
              builder: (BuildContext context, bool isUpdating, _) {
                return CircularProgressIndicator(
                  strokeWidth: 2,
                  value: isUpdating ? null : 0,
                );
              },
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: updating,
            builder: (BuildContext context, bool isUpdating, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed:
                    isUpdating ? null : () async => await updateStoredToken(),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: updating,
            builder: (BuildContext context, bool isUpdating, _) {
              return IconButton(
                icon: const Icon(Icons.delete),
                onPressed: isUpdating ? null : () async => await delete(),
              );
            },
          ),
          const SizedBox.square(
            dimension: 24,
            child: VerticalDivider(),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: darkMode,
            builder: (BuildContext context, bool value, _) {
              return IconButton(
                icon: Icon(value
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () async {
                  darkMode.value = !darkMode.value;
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => UpdaterPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
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
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextButton(
                      onPressed: () => controller.text = '',
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ),
            Row(children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 32.0),
                child: ToggleButtons(
                  borderRadius: BorderRadius.circular(6),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                  isSelected: [
                    ...filters.map(
                        (filter) => controller.text.contains(filter.filter)),
                  ],
                  onPressed: (index) {
                    final filter = filters[index];
                    final text = filter.filter;
                    if (controller.text.contains(text)) {
                      controller.text = controller.text.replaceAll(text, '');
                    } else {
                      controller.text += ' $text';
                    }
                    controller.text = controller.text.trim();
                  },
                  children: [
                    ...filters.map((filter) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(filter.name),
                      );
                    }),
                  ],
                ),
              ),
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
            StreamBuilder<List<PullRequest>>(
              stream: streamPullRequestsFromFirebase(),
              builder: (context, prSnapshot) {
                if (!prSnapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final pullRequests = prSnapshot.data!;
                return StreamBuilder<List<User>>(
                  stream: streamGooglersFromFirebase(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final googlers = snapshot.data!;
                    print(
                        'Build Table with ${googlers.length} googlers and ${pullRequests.length} prs');
                    return PullRequestTable(
                      pullRequests: pullRequests,
                      googlers: googlers,
                      filterStream: filterStream.stream,
                    );
                  },
                );
              },
            ),
            ValueListenableBuilder(
              valueListenable: updatingStatus,
              builder: (BuildContext context, String? value, _) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: value == null ? 0 : 32,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(value ?? ''),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
