import 'package:flutter/material.dart';

class FlexTable extends StatefulWidget {
  final List<Widget> headers;
  final List<FlexRow> rows;
  const FlexTable({super.key, required this.headers, required this.rows});

  @override
  State<FlexTable> createState() => _FlexTableState();
}

class _FlexTableState extends State<FlexTable> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: widget.headers),
        Expanded(
          child: ListView.separated(
            itemBuilder: (context, index) => widget.rows[index],
            separatorBuilder: (context, index) => const Divider(),
            itemCount: widget.rows.length,
          ),
        ),
      ],
    );
  }
}

class FlexRow extends StatelessWidget {
  final List<Widget> children;
  const FlexRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(children: children);
  }
}
