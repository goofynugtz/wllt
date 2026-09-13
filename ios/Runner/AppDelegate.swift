import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "sms_share_channel",
        binaryMessenger: controller.binaryMessenger
      )
      let groupId = "group.\(Bundle.main.bundleIdentifier ?? "").sms"
      channel.setMethodCallHandler { call, result in
        if call.method == "getPendingSms" {
          let text = UserDefaults(suiteName: groupId)?.string(forKey: "pending_sms_text") ?? ""
          if !text.isEmpty {
            UserDefaults(suiteName: groupId)?.removeObject(forKey: "pending_sms_text")
            UserDefaults(suiteName: groupId)?.synchronize()
          }
          result(text.isEmpty ? nil : text)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      // Total physical device RAM in bytes, used to gate the on-device AI model tier.
      let deviceInfoChannel = FlutterMethodChannel(
        name: "com.goofynugtz.wllt/device_info",
        binaryMessenger: controller.binaryMessenger
      )
      deviceInfoChannel.setMethodCallHandler { call, result in
        if call.method == "getTotalRamBytes" {
          result(Int64(ProcessInfo.processInfo.physicalMemory))
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
