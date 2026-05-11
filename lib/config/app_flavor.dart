import 'package:flutter/foundation.dart';

enum AppFlavor { dev, staging, release }

AppFlavor get kFlavor {
  if (kReleaseMode) return AppFlavor.release;
  if (kProfileMode) return AppFlavor.staging;
  return AppFlavor.dev;
}
