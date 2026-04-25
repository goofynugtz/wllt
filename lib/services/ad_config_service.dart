import 'package:flutter/foundation.dart';
import '../models/ad_config.dart';

/// Fetches and holds ad display configuration from the server.
///
/// Call [fetch] once on app launch. On any failure the config stays at
/// the safe default (all ads off) — we never fail open.
///
/// Listen to [config] with [ValueListenableBuilder] to reactively rebuild UI.
class AdConfigService {
  AdConfigService._();
  static final AdConfigService instance = AdConfigService._();

  // final ValueNotifier<AdConfig> config = ValueNotifier(const AdConfig(showBannerAd: true, showInlineAd: true));
  final ValueNotifier<AdConfig> config = ValueNotifier(const AdConfig());

  Future<void> fetch() async {
    try {
      // TODO: replace stub with real HTTP call when API endpoint is ready.
      //
      // final res = await http.get(Uri.parse(Env.adConfigUrl));
      // if (res.statusCode == 200) {
      //   final json = jsonDecode(res.body) as Map<String, dynamic>;
      //   config.value = AdConfig(
      //     showBannerAd: json['showBannerAd'] as bool? ?? false,
      //     showInlineAd: json['showInlineAd'] as bool? ?? false,
      //   );
      // }
      // On non-200: leave config.value unchanged (defaults = ads off).
    } catch (_) {
      // Fail silent. Do NOT reset config.value here — a previous successful
      // fetch may have already set a non-default config.
    }
  }
}
