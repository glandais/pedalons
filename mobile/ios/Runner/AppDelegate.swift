import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    AppDelegate.hideWebViewInputAccessory()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Hides the « ^ v ✓ » bar WKWebView puts above the keyboard. The rich post editor (the site's
  /// Tiptap editor in a WebView, `rich_markdown_editor_field.dart`) has its own toolbar, and the
  /// bar's arrows jump between form fields the editor doesn't have. webview_flutter offers no
  /// setting for it, so `WKContentView` — the view that becomes first responder inside every
  /// WKWebView — gets an `inputAccessoryView` returning nil. The override is added to that class
  /// only (`class_replaceMethod`), never to `UIResponder`: Flutter's own text fields keep theirs.
  /// It applies to every WKWebView of the app; the editor is the only one.
  private static func hideWebViewInputAccessory() {
    guard let contentView = NSClassFromString("WKContentView") else { return }
    let selector = #selector(getter: UIResponder.inputAccessoryView)
    guard let method = class_getInstanceMethod(contentView, selector) else { return }
    let noAccessory: @convention(block) (AnyObject) -> UIView? = { _ in nil }
    class_replaceMethod(
      contentView,
      selector,
      imp_implementationWithBlock(noAccessory),
      method_getTypeEncoding(method)
    )
  }
}
