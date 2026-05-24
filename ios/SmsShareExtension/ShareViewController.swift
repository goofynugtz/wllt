import UIKit
import Social

class ShareViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    guard
      let item = extensionContext?.inputItems.first as? NSExtensionItem,
      let attachment = item.attachments?.first,
      attachment.hasItemConformingToTypeIdentifier("public.plain-text")
    else {
      extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      return
    }

    attachment.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { data, _ in
      guard let text = data as? String else {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        return
      }
      let groupId = "group.\(Bundle.main.bundleIdentifier ?? "").sms"
      let defaults = UserDefaults(suiteName: groupId)
      defaults?.set(text, forKey: "pending_sms_text")
      defaults?.synchronize()
      self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
  }
}
