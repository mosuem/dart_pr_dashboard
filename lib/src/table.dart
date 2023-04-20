import 'package:flutter/material.dart';

class FlexTable<T extends Object> extends StatefulWidget {
  final List<String> titles;
  final List<Widget Function(T o)> headers;
  final List<T> rows;
  const FlexTable({
    super.key,
    required this.headers,
    required this.rows,
    required this.titles,
    required int sorted,
    required Future<bool> Function(dynamic pr) onTap,
  });

  @override
  State<FlexTable> createState() => _FlexTableState<T>();
}

class _FlexTableState<T extends Object> extends State<FlexTable<T>> {
  List<Widget> transform(T data) {
    return List.generate(
        widget.headers.length, (index) => widget.headers[index](data));
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemBuilder: (context, index) {
        if (index == 0) {
          return FlexRow(children: widget.titles.map((e) => Text(e)).toList());
        }
        return FlexRow(children: transform(widget.rows[index - 1]));
      },
      separatorBuilder: (context, index) => const Divider(),
      itemCount: widget.rows.length + 1,
    );
  }
}

class FlexRow<T extends Object> extends StatelessWidget {
  final List<Widget> children;
  const FlexRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children.map((e) => Expanded(child: e)).toList(),
    );
  }
}
