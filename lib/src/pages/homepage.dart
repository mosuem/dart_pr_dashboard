import 'package:flutter/material.dart';
import 'package:github/github.dart';

import '../../model.dart';
import '../filter/filter.dart';
import '../issue_table.dart';
import '../misc.dart';
import '../pullrequest_table.dart';

const presetFilters = [
  (name: 'Unlabeled', filter: r'labels:$^'),
  (name: 'Without reviewers', filter: r'reviewers:$^'),
  (
    name: 'Not authored by a Googler',
    filter: 'author:.*(?<!\\($gWithCircle\\))\$'
  ),
  (name: 'Not authored by a bot', filter: r'author:.*(?<!\[bot\])$'),
];

class MyHomePage extends StatefulWidget {
  final AppModel appModel;

  const MyHomePage({
    required this.appModel,
    super.key,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  var controller = TextEditingController();
  late TabController tabController;

  final googlersController = ValueNotifier<List<User>>([]);
  final filterStream = ValueNotifier<SearchFilter?>(null);

  List<({String filter, String name})> filters = [...presetFilters];

  @override
  void initState() {
    super.initState();

    () async {
      final localFilters = await loadFilters();
      setState(() {
        filters = [...presetFilters, ...localFilters];
      });
    }();

    tabController = TabController(vsync: this, length: 2);

    controller.addListener(() {
      setState(() {
        final filter =
            SearchFilter.fromFilter(controller.text, googlersController.value);
        filterStream.value = filter;
      });
    });
  }

  @override
  void dispose() {
    tabController.dispose();

    super.dispose();
  }

  ValueNotifier<bool> get darkModeSwitch => widget.appModel.darkMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart Triage Dashboard'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: widget.appModel.busy,
            builder: (BuildContext context, bool busy, _) {
              return Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: busy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : null,
                ),
              );
            },
          ),
          const SizedBox.square(dimension: 16),
          ValueListenableBuilder<bool>(
            valueListenable: darkModeSwitch,
            builder: (BuildContext context, bool value, _) {
              return IconButton(
                icon: Icon(value
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () async {
                  darkModeSwitch.value = !darkModeSwitch.value;
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'Pull Requests'),
            Tab(text: 'Issues'),
          ],
        ),
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
            Row(
              children: [
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
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  PullRequests(
                    appModel: widget.appModel,
                    filterStream: filterStream,
                  ),
                  Issues(
                    appModel: widget.appModel,
                    filterStream: filterStream,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PullRequests extends StatelessWidget {
  const PullRequests({
    super.key,
    required this.appModel,
    required this.filterStream,
  });

  final AppModel appModel;
  final ValueNotifier<SearchFilter?> filterStream;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appModel.pullrequests,
      builder: (context, pullrequests, child) {
        return ValueListenableBuilder(
          valueListenable: appModel.googlers,
          builder: (context, googlers, child) {
            return PullRequestTable(
              pullRequests: pullrequests,
              googlers: googlers,
              filterStream: filterStream,
            );
          },
        );
      },
    );
  }
}

class Issues extends StatelessWidget {
  const Issues({
    super.key,
    required this.appModel,
    required this.filterStream,
  });

  final AppModel appModel;
  final ValueNotifier<SearchFilter?> filterStream;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: appModel.issues,
      builder: (context, issues, child) {
        return ValueListenableBuilder(
          valueListenable: appModel.googlers,
          builder: (context, googlers, child) {
            return IssueTable(
              issues: issues,
              googlers: googlers,
              filterStream: filterStream,
            );
          },
        );
      },
    );
  }
}
