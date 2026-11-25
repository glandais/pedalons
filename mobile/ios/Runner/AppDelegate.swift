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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReceivedFilePlugin") {
      ReceivedFilePlugin.register(with: registrar)
    }
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

/// « Ouvrir avec Pédalons » (docs/LEDGER_*.md MOB-191). Un .gpx ouvert depuis Fichiers arrive **sur
/// place** (`LSSupportsOpeningDocumentsInPlace` vrai — sans quoi Fichiers ne propose pas l'app dans
/// « Ouvrir avec ») : l'URL pointe sur le fichier de la personne, lisible seulement avec l'accès
/// « security-scoped » attaché à cet objet `URL`, et seulement pendant l'événement. app_links n'en
/// remet à Dart que la chaîne : l'accès serait perdu. Le fichier est donc copié ici, dans
/// `tmp/received/`, pendant l'événement même ; Dart demande ensuite la copie par le canal
/// `received_file`, avec la chaîne que lui a remise app_links. Les délégués de scène sont appelés à
/// la suite sur le fil principal et la demande de Dart vient après : l'ordre avec app_links
/// n'importe pas. Une copie de `Documents/Inbox` (partage, Mail) passe par le même chemin, et
/// l'Inbox est vidée.
final class ReceivedFilePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private var copies: [String: [String: Any]] = [:]

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ReceivedFilePlugin()
    let channel = FlutterMethodChannel(
      name: "fr.pedalons.mobile/received_file", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "copy":
      let uri = (call.arguments as? [String: Any])?["uri"] as? String
      result(uri.flatMap { copies[$0] })
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    connectionOptions?.urlContexts.forEach { receive($0.url) }
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    URLContexts.forEach { receive($0.url) }
    return false
  }

  private func receive(_ url: URL) {
    guard url.isFileURL else { return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let manager = FileManager.default
    let dir = manager.temporaryDirectory.appendingPathComponent("received", isDirectory: true)
    try? manager.createDirectory(at: dir, withIntermediateDirectories: true)
    let target = dir.appendingPathComponent(url.lastPathComponent)
    var copied = false
    var coordinationError: NSError?
    // Un fichier d'iCloud Drive pas encore téléchargé l'est par la coordination.
    NSFileCoordinator().coordinate(
      readingItemAt: url, options: .withoutChanges, error: &coordinationError
    ) { readable in
      try? manager.removeItem(at: target)
      copied = (try? manager.copyItem(at: readable, to: target)) != nil
    }
    guard copied else { return }
    let size = (try? manager.attributesOfItem(atPath: target.path)[.size] as? NSNumber) ?? 0
    copies[url.absoluteString] = [
      "path": target.path, "name": url.lastPathComponent, "size": size.int64Value,
    ]
    if url.path.contains("/Documents/Inbox/") { try? manager.removeItem(at: url) }
  }
}
