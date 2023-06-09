import 'package:flutter/material.dart';

class Updater {
  final ValueNotifier<bool> status = ValueNotifier(false);
  final ValueNotifier<String?> text = ValueNotifier(null);

  Updater();

  void open(String message) {
    status.value = true;
    text.value = message;
  }

  void close() {
    status.value = false;
    text.value = null;
  }

  void set(String s) {
    text.value = s;
  }
}
