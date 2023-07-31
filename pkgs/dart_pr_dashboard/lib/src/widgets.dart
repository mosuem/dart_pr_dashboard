import 'package:flutter/material.dart';
import 'package:github/github.dart';

import 'misc.dart';

Text textTwoLines(String text) {
  return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
}

class LabelWidget extends StatelessWidget {
  final IssueLabel label;

  const LabelWidget(
    this.label, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = Color(int.parse('FF${label.color}', radix: 16));

    return Material(
      color: chipColor,
      shape: const StadiumBorder(),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Text(
          label.name,
          style: TextStyle(
            color: isLightColor(chipColor)
                ? Colors.grey.shade900
                : Colors.grey.shade100,
          ),
          // TODO: Replace textScaleFactor with textScaler w/ the next beta.
          // ignore: deprecated_member_use
          textScaleFactor: 0.75,
          // textScaler: const TextScaler.linear(0.75),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  final double height;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const SearchField({
    this.height = 36,
    this.hintText = 'Search',
    this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 175,
      height: height,
      child: TextField(
        maxLines: 1,
        onChanged: onChanged,
        decoration: InputDecoration(
          fillColor: Colors.grey.shade100,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}
