// Web stub for workmanager — all task scheduling is a no-op.

enum NetworkType { notRequired, connected, unmetered }

enum ExistingPeriodicWorkPolicy { keep, replace }

class Constraints {
  final NetworkType? networkType;
  const Constraints({this.networkType});
}

class Workmanager {
  Future<void> initialize(
    Function callback, {
    bool isInDebugMode = false,
  }) async {}

  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
  }) async {}

  Future<void> cancelByUniqueName(String uniqueName) async {}

  Future<bool> executeTask(
    Future<bool> Function(String, Map<String, dynamic>?) taskCallback,
  ) async =>
      true;
}
