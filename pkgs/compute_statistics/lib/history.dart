import 'package:collection/collection.dart';
import 'package:dart_triage_updater/update_type.dart';
import 'package:github/github.dart';

class History<T> {
  final T object;
  final UpdateType<T, T> type;
  final List<TimelineEvent> events;

  History(this.type, this.object, List<TimelineEvent> events)
      : events = events.sortedBy((event) =>
            event.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));

  /// LABELING
  Iterable<LabelEvent> get _labelEvents => events.whereType<LabelEvent>();
  Iterable<LabelEvent> get _addedLabels =>
      _labelEvents.where((label) => label.event == 'labeled');
  Iterable<LabelEvent> get _removedLabels =>
      _labelEvents.where((label) => label.event == 'unlabeled');
  Iterable<LabelEvent> get _labels =>
      _addedLabels.where((label) => !_removedLabels.contains(label));

  bool wasLabeledAt(DateTime time) =>
      _labels.any((label) => label.createdAt!.isBefore(time));

  Duration? get timeToLabel => _timeTo(_labels);

  /// STATE CHANGES

  Iterable<StateChangeIssueEvent> get _stateChangeEvents =>
      events.whereType<StateChangeIssueEvent>();
  Iterable<StateChangeIssueEvent> get _reopenedEvents =>
      _stateChangeEvents.where((element) => element.event == 'reopened');
  Iterable<StateChangeIssueEvent> get _closedEvents =>
      _stateChangeEvents.where((element) => element.event == 'closed');

  bool wasOpenAt(DateTime time) {
    final wasNeverClosed = _closedEvents.isEmpty;
    final wasReopened = _reopenedEvents.lastOrNull?.createdAt!
            .isAfter(_closedEvents.last.createdAt!) ??
        false;
    return wasNeverClosed || wasReopened;
  }

  /// COMMENTING
  Iterable<CommentEvent> get _commentEvents => events.whereType<CommentEvent>();

  Duration? get timeToComment => _timeTo(_commentEvents);

  Duration? _timeTo<S extends TimelineEvent>(Iterable<S> eventList) {
    return eventList.firstOrNull?.createdAt?.difference(type.createdAt(object));
  }
}
