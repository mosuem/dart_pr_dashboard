// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_strategy/url_strategy.dart';

import 'model.dart';
import 'src/pages/homepage.dart';

Future<void> main() async {
  setPathUrlStrategy();

  runApp(MyApp(appModel: AppModel()));
}

class MyApp extends StatefulWidget {
  final AppModel appModel;

  const MyApp({
    required this.appModel,
    super.key,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    widget.appModel.init().then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    const appName = 'Dart Triage Dashboard';

    return ValueListenableBuilder<bool>(
      valueListenable: widget.appModel.darkMode,
      builder: (BuildContext context, bool value, _) {
        Widget content;

        if (widget.appModel.inited) {
          content = MyHomePage(
            appModel: widget.appModel,
          );
        } else {
          content = Scaffold(
            appBar: AppBar(title: const Text(appName)),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return MaterialApp(
          title: appName,
          theme: value
              ? ThemeData.dark(useMaterial3: false)
              : ThemeData.light(useMaterial3: false),
          debugShowCheckedModeBanner: false,
          home: content,
        );
      },
    );
  }
}
