import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gates which on-device model tier [AiService] loads, by total device RAM.
/// Backed by a tiny native MethodChannel (ActivityManager.MemoryInfo on
/// Android, ProcessInfo.physicalMemory on iOS) — no plugin needed for one bool.
class DeviceCapability {
  DeviceCapability._();

  static const _channel = MethodChannel('com.goofynugtz.wllt/device_info');

  // ponytail: one global RAM cutoff, not tuned per chipset/GPU-delegate
  // support. Big tier is now a ~2.6GB litertlm model (was a 6.5GB one that
  // needed the old 6GB cutoff) so mid-range phones can take it too. Reported
  // RAM runs below the marketed figure (OS reserves some), so 4GB reported
  // reliably catches real 6GB-marketed phones while excluding 3/4GB budget
  // ones. Revisit if the big tier proves too slow near this line.
  static const _bigModelMinRamBytes = 4 * 1024 * 1024 * 1024; // 4GB

  /// True if this device should get the larger on-device model tier.
  /// False on web and on any error reading device RAM — safe default, falls
  /// back to the small model rather than risking an OOM on the big one.
  static Future<bool> get supportsBigModel async {
    if (kIsWeb) return false;
    try {
      final bytes = await _channel.invokeMethod<int>('getTotalRamBytes');
      return (bytes ?? 0) >= _bigModelMinRamBytes;
    } catch (_) {
      return false;
    }
  }
}
