import 'dart:async';
import 'package:flutter/material.dart';

class FlexTable<T extends Object> extends StatefulWidget {
  final List<FlexColumn> columns;
  final Stream<List<T>> rowStream;
  final internalRowStream = StreamController<List<T>>();

  final Future<bool> Function(T pr) onTap;

  FlexTable({
    super.key,
    required this.columns,
    required this.rowStream,
    required this.onTap,
  });

  @override
  State<FlexTable> createState() => _FlexTableState<T>();
}

class _FlexTableState<T extends Object> extends State<FlexTable<T>> {
  List<Widget> transform(T data) => List.generate(
        widget.columns.length,
        (index) => widget.columns[index].render(data),
      );

  late int sortedKey;
  int ascending = 1;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: widget.rowStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        resetSorting();
        sortRows(snapshot.data!);
        return StreamBuilder<List<T>>(
            stream: widget.internalRowStream.stream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final rows = snapshot.data!;
              return ListView.separated(
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return HeaderRow(
                      columns: widget.columns,
                      isAscending: ascending == 1,
                      sortedColumn: sortedKey,
                      onTap: List.generate(widget.columns.length, (index) {
                        return () {
                          if (sortedKey == index) {
                            ascending = ascending * -1;
                          } else {
                            ascending = 1;
                            sortedKey = index;
                          }

                          sortRows(rows);
                        };
                      }),
                      children: List.generate(
                        widget.columns.length,
                        (index) => Text(
                          widget.columns[index].title,
                          style: index == sortedKey
                              ? const TextStyle(fontWeight: FontWeight.bold)
                              : null,
                        ),
                      ),
                    );
                  }
                  return FlexRow(
                    columns: widget.columns,
                    onTap: () => widget.onTap(rows[index - 1]),
                    children: transform(rows[index - 1]),
                  );
                },
                separatorBuilder: (context, index) => const Divider(),
                itemCount: rows.length + 1,
              );
            });
      },
    );
  }

  void resetSorting() {
    sortedKey = widget.columns.indexWhere((column) => column.initiallySort);
    ascending = -1;
  }

  void sortRows(List<T> rows) {
    widget.internalRowStream.sink.add(rows
      ..sort((a, b) =>
          widget.columns[sortedKey].compareFunction(a, b) * ascending));
  }
}

class FlexColumn<T extends Object, S extends Object> {
  final String title;
  final int flex;

  final S? Function(T pr) valueFunction;
  final String Function(S value)? renderer;
  final int Function(S a, S b)? comparator;
  final Widget Function(T pr)? renderFunction;

  final bool initiallySort;

  FlexColumn({
    required this.title,
    required this.valueFunction,
    this.initiallySort = false,
    this.renderer,
    this.flex = 10,
    this.comparator,
    this.renderFunction,
  });

  Widget render(T pr) {
    if (renderFunction != null) {
      return renderFunction!(pr);
    } else {
      return Text(transformFunction(pr));
    }
  }

  String transformFunction(T pr) {
    final v = valueFunction(pr);
    if (v == null) return '';
    return renderer != null ? renderer!(v) : v.toString();
  }

  int compareFunction(T a, T b) {
    final va = valueFunction(a);
    final vb = valueFunction(b);
    if (va == null) return -1;
    if (vb == null) return 1;
    if (comparator != null) {
      return comparator!(va, vb);
    } else {
      //TODO(mosum): Add an assert to emit a warning iff comparator == null &&
      // S is not Comparable
      return (va as Comparable).compareTo(vb);
    }
  }
}

class FlexRow<T extends Object> extends StatelessWidget {
  final List<Widget> children;
  final List<FlexColumn> columns;
  final void Function() onTap;
  const FlexRow({
    super.key,
    required this.children,
    required this.columns,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: List.generate(
          children.length,
          (index) => Expanded(
            flex: columns[index].flex,
            child: children[index],
          ),
        ),
      ),
    );
  }
}

class HeaderRow<T extends Object> extends StatelessWidget {
  final List<Widget> children;
  final List<FlexColumn> columns;
  final List<void Function()> onTap;
  final bool isAscending;
  final int sortedColumn;

  const HeaderRow({
    super.key,
    required this.sortedColumn,
    required this.isAscending,
    required this.children,
    required this.columns,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        children.length,
        (index) => Expanded(
          flex: columns[index].flex,
          child: InkWell(
            onTap: onTap[index],
            child: Row(
              children: [
                Expanded(child: children[index]),
                if (sortedColumn == index)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      isAscending ? Icons.expand_more : Icons.expand_less,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
