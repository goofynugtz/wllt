/// Display flags returned by the ad-config API.
/// All fields default to false — ads are off until the server enables them.
class AdConfig {
  final bool showBannerAd;
  final bool showInlineAd;
  final String bannerAdUnitId;

  const AdConfig({
    this.showBannerAd = false,
    this.showInlineAd = false,
    this.bannerAdUnitId = 'ca-app-pub-3138229234579129/4213812441',
  });
}
