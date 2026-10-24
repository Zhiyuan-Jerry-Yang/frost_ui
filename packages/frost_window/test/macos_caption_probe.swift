import Cocoa
import FlutterMacOS

final class ProbeMessenger: NSObject, FlutterBinaryMessenger {
  var calls: [String] = []
  func send(onChannel channel: String, message: Data?) {
    guard let message = message else { return }
    let call = FlutterStandardMethodCodec.sharedInstance().decodeMethodCall(message)
    calls.append(call.method)
  }
  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    send(onChannel: channel, message: message)
    callback?(nil)
  }
  func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection { 1 }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}

final class ProbeRegistrar: NSObject, FlutterPluginRegistrar {
  let probeMessenger = ProbeMessenger()
  var messenger: FlutterBinaryMessenger { probeMessenger }
  var textures: FlutterTextureRegistry { preconditionFailure("Texture registry is outside this native window test") }
  let view: NSView?
  var viewController: NSViewController? { nil }
  var plugin: FrostWindowPlugin?
  init(view: NSView) { self.view = view }
  func addMethodCallDelegate(_ delegate: FlutterPlugin, channel: FlutterMethodChannel) { plugin = delegate as? FrostWindowPlugin }
  func addApplicationDelegate(_ delegate: FlutterAppLifecycleDelegate) {}
  func register(_ factory: FlutterPlatformViewFactory, withId factoryId: String) {}
  func publish(_ value: NSObject) {}
  func lookupKey(forAsset asset: String) -> String { asset }
  func lookupKey(forAsset asset: String, fromPackage package: String) -> String { asset }
}

final class ProbeView: NSView { override var isFlipped: Bool { true } }

@main struct AppKitProbe {
  static func main() {
    _ = NSApplication.shared
    let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 960, height: 640), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let view = ProbeView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
    view.autoresizingMask = [.width, .height]
    window.contentView = view
    let kinds: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    let original = kinds.map { window.standardWindowButton($0)! }
    let registrar = ProbeRegistrar(view: view)
    FrostWindowPlugin.register(with: registrar)
    guard let plugin = registrar.plugin else { fatalError("Plugin registration failed") }
    var checks = [String: Bool]()
    checks["fullSizeContentView"] = window.styleMask.contains(.fullSizeContentView)
    checks["hiddenNativeTitle"] = window.titleVisibility == .hidden
    checks["transparentTitlebar"] = window.titlebarAppearsTransparent
    checks["originalTrafficLightsRetained"] = zip(kinds, original).allSatisfy { window.standardWindowButton($0.0) === $0.1 }
    checks["allThreeNativeButtonsVisible"] = original.allSatisfy { !$0.isHiddenOrHasHiddenAncestor }
    var snapshot: [String: Any] = [:]
    plugin.handle(FlutterMethodCall(methodName: "getState", arguments: nil)) { snapshot = $0 as? [String: Any] ?? [:] }
    let bounds = snapshot["nativeControls"] as? [CGFloat] ?? []
    checks["nativeControlsMode"] = snapshot["captionMode"] as? String == "nativeControls"
    checks["noFlutterButtonDuplicates"] = (snapshot["leftButtons"] as? [String]) == [] && (snapshot["rightButtons"] as? [String]) == []
    checks["nonemptyNativeControlBounds"] = bounds.count == 4 && bounds[2] > bounds[0] && bounds[3] > bounds[1]
    checks["nativeControlsOnLeft"] = bounds.count == 4 && bounds[2] < view.bounds.width / 2
    checks["fullSizeContentKeepsTopControlsInContent"] = window.contentView === view && bounds.count == 4 && bounds[1] >= 0
    checks["nativeControlsWithinContent"] = bounds.count == 4 && bounds[0] >= 0 && bounds[1] >= 0 && bounds[2] <= view.bounds.width && bounds[3] <= view.bounds.height
    var configured = false
    plugin.handle(FlutterMethodCall(methodName: "configure", arguments: [320.0, 480.0])) { configured = $0 == nil }
    checks["minimumSizeConfigured"] = configured && window.contentMinSize == NSSize(width: 320, height: 480)
    window.setContentSize(NSSize(width: 760, height: 540))
    checks["nativeResizePublishesState"] = registrar.probeMessenger.calls.filter { $0 == "stateChanged" }.count > 1
    let output: [String: Any] = ["checks": checks, "state": snapshot, "flutterViewBounds": [view.bounds.width, view.bounds.height], "windowWasShown": false]
    let data = try! JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
    print(String(data: data, encoding: .utf8)!)
    window.close()
    if checks.values.contains(false) { exit(1) }
  }
}
