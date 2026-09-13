import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_helper.dart';

/// Periodic background task that reschedules medication reminders.
///
/// Android's Doze mode can delay or drop exact alarms after a few days of
/// inactivity. WorkManager uses Jetpack's WorkManager under the hood, which
/// is designed to survive Doze — it will execute the task even when the app
/// is in the "restricted" battery bucket, albeit with some delay.
///
/// The task runs every 12 hours (the minimum feasible interval for a
/// periodic WorkManager job on Android). Each run calls
/// [NotificationHelper.rescheduleAllMedicationReminders] to re-plant any
/// reminders that Android may have dropped.
class WorkManagerService {
  static const String _taskName = 'com.ritme.ritme.reschedule_medication';
  static const Duration _period = Duration(hours: 12);
  static bool _initialized = false;

  /// Initialize WorkManager and register the periodic reschedule task.
  /// Call this once in main() after notification initialization.
  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return;

    await Workmanager().initialize(
      callbackDispatcher,
    );

    // Register the periodic task. WorkManager deduplicates by tag, so
    // calling this multiple times is safe — it will not create duplicates.
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: _period,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.linear,
      initialDelay: Duration.zero,
    );

    _initialized = true;
    developer.log(
      'WorkManagerService initialized — periodic reschedule every $_period',
      name: 'WorkManagerService',
    );
  }
}

/// Top-level callback that WorkManager invokes in the background isolate.
/// Must be a top-level function (not a method on a class) per WorkManager
/// requirements.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != WorkManagerService._taskName) return true;

    developer.log(
      'WorkManager task executing: $taskName',
      name: 'WorkManagerService',
    );

    try {
      final count =
          await NotificationHelper.instance.rescheduleAllMedicationReminders();
      developer.log(
        'WorkManager rescheduled $count medication reminders',
        name: 'WorkManagerService',
      );
    } catch (e, stackTrace) {
      developer.log(
        'WorkManager reschedule failed: $e',
        name: 'WorkManagerService',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return true;
  });
}
