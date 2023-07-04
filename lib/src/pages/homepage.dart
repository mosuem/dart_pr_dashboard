import 'package:flutter/material.dart';
import 'package:github/github.dart';

import '../../dashboard_type.dart';
import '../filter/filter.dart';
import '../issue_table.dart';
import '../misc.dart';
import '../pullrequest_table.dart';
import '../updater.dart';
import 'updaterpage.dart';

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

class MyHomePage extends StatefulWidget {
  final ValueNotifier<bool> darkModeSwitch;
  final ValueNotifier<DashboardType> typeSwitch;
  final DashboardType type;

  final Updater updater = Updater();

  final ValueNotifier<List<User>> googlers;

  final ValueNotifier<List<PullRequest>> pullrequests;
  final ValueNotifier<List<Issue>> issues;

  MyHomePage({
    super.key,
    required this.darkModeSwitch,
    required this.pullrequests,
    required this.googlers,
    required this.type,
    required this.issues,
    required this.typeSwitch,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var controller = TextEditingController();

  final googlersController = ValueNotifier<List<User>>([]);
  final filterStream = ValueNotifier<SearchFilter?>(null);

  @override
  void initState() {
    super.initState();

    controller.addListener(() {
      setState(() {
        final filter =
            SearchFilter.fromFilter(controller.text, googlersController.value);
        filterStream.value = filter;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart PR Dashboard'),
        actions: [
          SizedBox.square(
            dimension: 16,
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.updater.status,
              builder: (BuildContext context, bool isUpdating, _) {
                return CircularProgressIndicator(
                  strokeWidth: 2,
                  value: isUpdating ? null : 0,
                );
              },
            ),
          ),
          ValueListenableBuilder<DashboardType>(
            valueListenable: widget.typeSwitch,
            builder: (BuildContext context, DashboardType value, _) {
              return DropdownButton<DashboardType>(
                value: widget.typeSwitch.value,
                items: DashboardType.values
                    .map((e) => DropdownMenuItem<DashboardType>(
                          value: e,
                          child: Text(e.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) widget.typeSwitch.value = value;
                },
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.updater.status,
            builder: (BuildContext context, bool isUpdating, _) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: isUpdating
                    ? null
                    : () async =>
                        await updateStoredToken(widget.updater, widget.type),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.updater.status,
            builder: (BuildContext context, bool isUpdating, _) {
              return IconButton(
                icon: const Icon(Icons.delete),
                onPressed: isUpdating
                    ? null
                    : () async => await delete(widget.updater),
              );
            },
          ),
          const SizedBox.square(
            dimension: 24,
            child: VerticalDivider(),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.darkModeSwitch,
            builder: (BuildContext context, bool value, _) {
              return IconButton(
                icon: Icon(value
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined),
                onPressed: () async {
                  widget.darkModeSwitch.value = !widget.darkModeSwitch.value;
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
                  builder: (BuildContext context) => UpdaterPage(
                    updater: widget.updater,
                  ),
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
            if (widget.type == DashboardType.pullrequests)
              PullRequests(
                pullrequests: widget.pullrequests,
                googlers: widget.googlers,
                filterStream: filterStream,
              )
            else if (widget.type == DashboardType.issues)
              Issues(
                issues: widget.issues,
                googlers: widget.googlers,
                filterStream: filterStream,
              ),
            ValueListenableBuilder<String?>(
              valueListenable: widget.updater.text,
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

class PullRequests extends StatelessWidget {
  const PullRequests({
    super.key,
    required this.filterStream,
    required this.pullrequests,
    required this.googlers,
  });

  final ValueNotifier<List<PullRequest>> pullrequests;
  final ValueNotifier<List<User>> googlers;
  final ValueNotifier<SearchFilter?> filterStream;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: pullrequests,
      builder: (context, pullrequests, child) {
        return ValueListenableBuilder(
          valueListenable: googlers,
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
    required this.filterStream,
    required this.issues,
    required this.googlers,
  });

  final ValueNotifier<List<Issue>> issues;
  final ValueNotifier<List<User>> googlers;
  final ValueNotifier<SearchFilter?> filterStream;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: issues,
      builder: (context, issues, child) {
        return ValueListenableBuilder(
          valueListenable: googlers,
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
