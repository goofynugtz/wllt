/// Display flags returned by the ad-config API.
/// All fields default to false — ads are off until the server enables them.
class AdConfig {
  final bool showBannerAd;  // thin strip above bottom nav
  final bool showInlineAd;  // card embedded in home content feed

  const AdConfig({
    this.showBannerAd = false,
    this.showInlineAd = false,
  });
}
