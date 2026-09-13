import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Gates which on-device model tier [AiService] loads, by total device RAM.
/// Backed by a tiny native MethodChannel (ActivityManager.MemoryInfo on
/// Android, ProcessInfo.physicalMemory on iOS) — no plugin needed for one bool.
class DeviceCapability {
  DeviceCapability._();

  static const _channel = MethodChannel('com.goofynugtz.wllt/device_info');

  // ponytail: one global RAM cutoff, not tuned per chipset/GPU-delegate
  // support. Reported RAM runs below the marketed figure (OS reserves some),
  // so 6GB reported reliably catches real 8GB-marketed phones while
  // excluding 4/6GB ones. Revisit if the big tier proves too slow near this line.
  static const _bigModelMinRamBytes = 6 * 1024 * 1024 * 1024; // 6GB

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
