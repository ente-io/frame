import 'package:photos/events/event.dart';

class SyncStatusUpdate extends Event {
  final int completed;
  final int total;
  final bool wasStopped;
  final SyncStatus status;
  final String reason;

  SyncStatusUpdate(
    this.status, {
    this.completed,
    this.total,
    this.wasStopped = false,
    this.reason = "",
  });
}

enum SyncStatus {
  not_started,
  in_progress,
  paused,
  completed,
  error,
}