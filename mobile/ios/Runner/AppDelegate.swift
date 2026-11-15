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
    AppDelegate.letWebViewFocusShowKeyboard()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Hides the « ^ v ✓ » bar WKWebView puts above the keyboard. The rich text editor (the site's
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

  /// Lets a focus given by JavaScript open the keyboard. The rich text editor focuses its text when
  /// it opens and after an image is inserted (`pedalons.focusEnd`), but WKWebView only shows the
  /// keyboard for a focus that follows a tap (`keyboardDisplayRequiresUserAction`, private, with no
  /// setting in webview_flutter). `WKContentView`'s focus handler is told every focus is the
  /// person's — the approach of react-native-webview. If WebKit renames the method, nothing is
  /// replaced and the editor simply waits for a tap, as before.
  private static func letWebViewFocusShowKeyboard() {
    guard let contentView = NSClassFromString("WKContentView") else { return }
    let selector = sel_getUid(
      "_elementDidFocus:userIsInteracting:blurPreviousNode:activityStateChanges:userObject:")
    guard let method = class_getInstanceMethod(contentView, selector) else { return }
    typealias Focus = @convention(c) (
      AnyObject, Selector, UnsafeRawPointer, Bool, Bool, UInt, AnyObject?
    ) -> Void
    let original = unsafeBitCast(method_getImplementation(method), to: Focus.self)
    let focusAsUser:
      @convention(block) (AnyObject, UnsafeRawPointer, Bool, Bool, UInt, AnyObject?) -> Void = {
        view, info, _, blurPrevious, activityChanges, userObject in
        original(view, selector, info, true, blurPrevious, activityChanges, userObject)
      }
    method_setImplementation(method, imp_implementationWithBlock(focusAsUser))
  }
}
