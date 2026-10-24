import Cocoa
import FlutterMacOS

/// The AppKit title region remains native; only its text/background are hidden.
/// Its standard buttons stay in AppKit's view hierarchy and keep system behavior.
public final class FrostWindowPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel
  private weak var view: NSView?
  private weak var window: NSWindow?
  private var regions: [NSRect] = []
  private var observers: [NSObjectProtocol] = []
  private var workspaceObserver: NSObjectProtocol?
  private var eventMonitor: Any?
  private var revision: Int64 = 0

  private init(channel: FlutterMethodChannel, view: NSView?) {
    self.channel = channel
    self.view = view
    super.init()
    attach()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "frost_window", binaryMessenger: registrar.messenger)
    let instance = FrostWindowPlugin(channel: channel, view: registrar.view)
    registrar.addMethodCallDelegate(instance, channel: channel)
    channel.invokeMethod("registered", arguments: nil)
  }

  deinit {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    if let token = workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
  }

  private func attach() {
    guard window == nil, let window = view?.window else { return }
    self.window = window
    window.styleMask.insert(.fullSizeContentView)
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = false
    window.titlebarSeparatorStyle = .none

    let names: [Notification.Name] = [
      NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
      NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
      NSWindow.didResizeNotification, NSWindow.didChangeBackingPropertiesNotification,
      NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification,
    ]
    for name in names {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in self?.publish() })
    }
    // AppKit can reposition native controls independently of the Flutter view,
    // including the title-region animation into/out of full screen.
    var observed = Set<ObjectIdentifier>()
    for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      var current: NSView? = window.standardWindowButton(kind)
      while let control = current, control !== window.contentView {
        if observed.insert(ObjectIdentifier(control)).inserted {
          control.postsFrameChangedNotifications = true
          observers.append(NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: control, queue: .main) { [weak self] _ in self?.publish() })
        }
        current = control.superview
      }
    }
    workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.publish() }
    eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
      guard let self = self, let view = self.view, event.window === self.window else { return event }
      let local = view.convert(event.locationInWindow, from: nil)
      let point = NSPoint(x: local.x, y: view.isFlipped ? local.y : view.bounds.height - local.y)
      if self.nativeControls().contains(point) || !self.regions.contains(where: { $0.contains(point) }) { return event }
      if event.clickCount == 2 { self.window?.performZoom(nil) }
      else { self.window?.performDrag(with: event) }
      return nil
    }
    publish()
  }

  private func nativeControls() -> NSRect {
    guard let window = window, let view = view else { return .zero }
    var union = NSRect.null
    for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      guard let button = window.standardWindowButton(kind), !button.isHiddenOrHasHiddenAncestor else { continue }
      let rect = button.convert(button.bounds, to: view)
      let top = view.isFlipped ? rect.minY : view.bounds.height - rect.maxY
      let logical = NSRect(x: rect.minX, y: top, width: rect.width, height: rect.height)
      guard logical.maxY > 0, logical.minY < view.bounds.height else { continue }
      union = union.union(logical)
    }
    return union.isNull ? .zero : union
  }

  private func state() -> [String: Any] {
    let bounds = nativeControls()
    return [
      "captionMode": "nativeControls", "leftButtons": [String](), "rightButtons": [String](),
      "nativeControls": [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY],
      "maximized": window?.isZoomed ?? false, "active": window?.isKeyWindow ?? false,
      "minimized": window?.isMiniaturized ?? false,
      "reduceTransparency": NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
      "revision": revision,
    ]
  }

  private func publish() {
    guard window != nil else { return }
    revision += 1
    channel.invokeMethod("stateChanged", arguments: state())
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    attach()
    guard let window = window else {
      result(FlutterError(code: "window_unavailable", message: "No AppKit window is attached.", details: nil))
      return
    }
    func invalid() { result(FlutterError(code: "invalid_arguments", message: "Invalid window request.", details: nil)) }
    switch call.method {
    case "getDiagnostics", "getState": result(state()); return
    case "configure":
      guard let size = call.arguments as? [NSNumber], size.count == 2,
        size.allSatisfy({ $0.doubleValue.isFinite && $0.doubleValue > 0 }) else { invalid(); return }
      window.contentMinSize = NSSize(width: size[0].doubleValue, height: size[1].doubleValue)
    case "setRegions":
      guard let rows = call.arguments as? [[Any]] else { invalid(); return }
      var next: [NSRect] = []
      for row in rows {
        guard row.count == 5, let kind = row[4] as? String,
          let x1 = row[0] as? NSNumber, let y1 = row[1] as? NSNumber,
          let x2 = row[2] as? NSNumber, let y2 = row[3] as? NSNumber else { invalid(); return }
        let values = [x1, y1, x2, y2].map { $0.doubleValue }
        guard values.allSatisfy({ $0.isFinite }), values[2] >= values[0], values[3] >= values[1],
          kind == "caption" || kind == "maximize" else { invalid(); return }
        if kind == "caption" { next.append(NSRect(x: values[0], y: values[1], width: values[2] - values[0], height: values[3] - values[1])) }
      }
      regions = next
    case "setToolbar":
      guard let args = call.arguments as? [String: Any], let title = args["title"] as? String,
        let dark = args["dark"] as? Bool else { invalid(); return }
      window.title = title
      // Match the application's explicit appearance without changing system preferences.
      window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    case "setResizeBorder", "setBackdrop": break // AppKit owns resize edges; Mica is unavailable.
    case "minimize": window.performMiniaturize(nil)
    case "toggleMaximized": window.performZoom(nil)
    case "close": window.performClose(nil)
    default: result(FlutterMethodNotImplemented); return
    }
    result(nil)
  }
}
