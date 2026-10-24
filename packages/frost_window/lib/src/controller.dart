import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frost_ui/frost_ui.dart';

/// Whether a native desktop window plugin can be contacted. Actual decoration
/// geometry and controls come from FrostWindowState, independently of Theme.
bool get frostUsesCustomTitleBar =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
      _ => false,
    };

/// The requested system backdrop. [none] means no system backdrop: the app's
/// ambient image or solid base supplies the window background.
enum FrostWindowBackdrop { none, mica, micaAlt }

class FrostWindowFailure implements Exception {
  const FrostWindowFailure();
}

/// Sanitised native diagnostics: method, failure code and native frame step.
/// Never contains window contents, input or titles.
typedef FrostWindowDiagnosticWriter = Future<void> Function(Map<String, Object?> diagnostic);

@immutable
class FrostWindowState {
  const FrostWindowState({
    this.maximized = false,
    this.active = true,
    this.minimized = false,
    this.backdropActive = false,
    this.backdropAvailable = false,
    this.reduceTransparency = false,
    this.hoveredButton = '',
    this.pressedButton = '',
    this.revision = -1,
    this.captionMode = FrostCaptionMode.client,
    this.leftButtons = const [],
    this.rightButtons = const [FrostCaptionAction.minimize, FrostCaptionAction.maximize, FrostCaptionAction.close],
    this.nativeControls = Rect.zero,
  });

  factory FrostWindowState.fromMap(Map<Object?, Object?> value) => FrostWindowState(
    captionMode: switch (value['captionMode']) {
      'nativeControls' => FrostCaptionMode.nativeControls,
      'system' => FrostCaptionMode.system,
      null || 'client' => FrostCaptionMode.client,
      _ => throw const FormatException('Invalid native caption mode'),
    },
    leftButtons: _buttons(value['leftButtons'], const []),
    rightButtons: _buttons(value['rightButtons'], const [FrostCaptionAction.minimize, FrostCaptionAction.maximize, FrostCaptionAction.close]),
    nativeControls: _nativeRect(value['nativeControls']),
    maximized: value['maximized'] == true,
    active: value['active'] != false,
    minimized: value['minimized'] == true,
    backdropActive: value['backdropActive'] == true,
    backdropAvailable: value['backdropAvailable'] == true,
    reduceTransparency: value['reduceTransparency'] == true,
    hoveredButton: value['hoveredButton'] as String? ?? '',
    pressedButton: value['pressedButton'] as String? ?? '',
    revision: (value['revision'] as num?)?.toInt() ?? 0,
  );

  final FrostCaptionMode captionMode;
  final List<FrostCaptionAction> leftButtons, rightButtons;
  final Rect nativeControls;

  static List<FrostCaptionAction> _buttons(Object? value, List<FrostCaptionAction> defaults) =>
      value == null ? defaults : List.unmodifiable((value as List).map((name) => FrostCaptionAction.values.byName(name as String)));
  static Rect _nativeRect(Object? value) {
    if (value == null) return Rect.zero;
    final coordinates = (value as List).cast<num>();
    if (coordinates.length != 4 || coordinates.any((n) => !n.isFinite) || coordinates[2] < coordinates[0] || coordinates[3] < coordinates[1]) {
      throw const FormatException('Invalid native control bounds');
    }
    return Rect.fromLTRB(coordinates[0].toDouble(), coordinates[1].toDouble(), coordinates[2].toDouble(), coordinates[3].toDouble());
  }

  final bool maximized;
  final bool active;
  final bool minimized;

  /// Actual native support and system preference, not just the requested mode.
  /// Updated when Windows transparency, contrast or theme settings change.
  final bool backdropActive;

  /// Native DWM support and current system preferences permit a backdrop,
  /// independently of the requested mode. Updated with system setting changes.
  final bool backdropAvailable;

  /// Effective Windows transparency/high-contrast preference.
  final bool reduceTransparency;

  /// Native caption button under the pointer, as hit-tested by Windows so
  /// Snap Layouts keeps working: `maximize` or empty.
  final String hoveredButton;
  final String pressedButton;

  /// Native event order; a stale reply never overwrites a newer event.
  final int revision;
}

/// Talks to the native window plugin. One controller per window.
class FrostWindowController extends ChangeNotifier implements ValueListenable<FrostWindowState> {
  FrostWindowController({
    required this.minimumSize,
    this.channel = const MethodChannel('frost_window'),
    this.diagnosticWriter,
    this.registrationTimeout = const Duration(seconds: 5),
  });

  /// Smallest logical window size the user can resize to.
  final Size minimumSize;
  final MethodChannel channel;
  final FrostWindowDiagnosticWriter? diagnosticWriter;
  final Duration registrationTimeout;

  final Completer<void> _registration = Completer<void>();
  final _backRequests = ChangeNotifier();
  Future<void> _diagnosticTask = Future.value();
  FrostWindowState _state = const FrostWindowState();
  Future<void>? _initializing;
  bool _initialized = false;
  bool _failed = false;
  bool _disposed = false;
  String? _failureMethod;
  String? _failureCode;

  FrostWindowState get state => _state;
  @override
  FrostWindowState get value => _state;
  bool get failed => _failed;
  bool get ready => _initialized && !_failed && !_disposed;
  String? get failureMethod => _failureMethod;
  String? get failureCode => _failureCode;

  /// Native Back requests: Alt+Left, the mouse back button and the browser
  /// back app command. They arrive here instead of as key events.
  void addBackListener(VoidCallback listener) => _backRequests.addListener(listener);
  void removeBackListener(VoidCallback listener) => _backRequests.removeListener(listener);

  Future<void> initialize() {
    if (_initialized || _disposed) return Future.value();
    return _initializing ??= _initialize().whenComplete(() => _initializing = null);
  }

  Future<void> _initialize() async {
    channel.setMethodCallHandler((call) async {
      if (_disposed) return;
      switch (call.method) {
        case 'navigateBack':
          _backRequests.notifyListeners();
        case 'registered':
          if (!_registration.isCompleted) _registration.complete();
        case 'stateChanged':
          if (!_registration.isCompleted) _registration.complete();
          if (call.arguments case final Map<Object?, Object?> arguments) _acceptState(arguments);
      }
    });
    // Dart can start before the plugin registers its channel. Probe an
    // already registered host or await its explicit registration event; never
    // race the first command against native startup.
    try {
      await channel.invokeMethod<Object?>('getDiagnostics');
      if (!_registration.isCompleted) _registration.complete();
    } on MissingPluginException {
      _logDiagnostic('bootstrap', 'waiting_registration');
    } on PlatformException {
      _recordFailure('bootstrap', 'platform_error');
      throw const FrostWindowFailure();
    }
    try {
      await _registration.future.timeout(registrationTimeout);
    } on TimeoutException {
      _recordFailure('bootstrap', 'registration_timeout');
      throw const FrostWindowFailure();
    }
    if (_disposed) return;
    await _invoke<void>('configure', [minimumSize.width, minimumSize.height]);
    final result = await _invoke<Object?>('getState');
    if (_disposed) return;
    if (result is! Map) {
      _recordFailure('getState', 'invalid_state');
      throw const FrostWindowFailure();
    }
    _initialized = true;
    _failed = false;
    _failureMethod = null;
    _failureCode = null;
    _acceptState(Map<Object?, Object?>.from(result));
    notifyListeners();
  }

  void _acceptState(Map<Object?, Object?> value) {
    final next = FrostWindowState.fromMap(value);
    // A reply to the startup query can arrive after a newer native event.
    if (next.revision < _state.revision || _disposed) return;
    _state = next;
    notifyListeners();
  }

  Future<void> minimize() => _invoke<void>('minimize');
  Future<void> toggleMaximized() => _invoke<void>('toggleMaximized');
  Future<void> close() => _invoke<void>('close');

  /// Windows-only keyboard/programmatic menu. Linux opens its compositor menu
  /// from the original native right-click event; macOS has no window menu.
  Future<void> showSystemMenu() => _invoke<void>('showSystemMenu');

  /// Logical-pixel rectangles (left, top, right, bottom, kind) where kind is
  /// `caption` (drag/double-click/system menu) or `maximize` (Snap Layouts).
  Future<void> setRegions(List<List<Object>> regions) => _invoke<void>('setRegions', regions);

  /// Sets the Windows top resize strip or Linux edge strips, in logical pixels.
  /// AppKit owns macOS resize edges independently of this setting.
  Future<void> setResizeBorder(double width) => _invoke<void>('setResizeBorder', width);

  /// Native window title (taskbar, Alt+Tab) and dark-mode window chrome.
  Future<void> setToolbar({required String title, required bool dark}) => _invoke<void>('setToolbar', {'title': title, 'dark': dark});

  /// Unsupported systems and disabled transparency return inactive normally.
  Future<void> setBackdrop(FrostWindowBackdrop backdrop, {required bool reduceTransparency}) =>
      _invoke<void>('setBackdrop', {'backdrop': backdrop.name, 'reduceTransparency': reduceTransparency});

  /// Puts an image on the clipboard as a 32-bit sRGB BITMAPV5 [dib] plus the
  /// same image as [png]. Both must describe the same size.
  Future<void> copyImage({required Uint8List dib, required Uint8List png}) => _invoke<void>('copyImage', {'dib': dib, 'png': png});

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (_disposed) return null;
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      _recordFailure(method, switch (error.code) {
        'window_unavailable' || 'invalid_arguments' || 'clipboard_unavailable' => error.code,
        _ => 'platform_error',
      }, error.details);
      throw const FrostWindowFailure();
    } on MissingPluginException {
      _recordFailure(method, 'missing_plugin');
      throw const FrostWindowFailure();
    }
  }

  void _recordFailure(String method, String code, [Object? details]) {
    if (_disposed) return;
    _failed = true;
    _initialized = false;
    _failureMethod = method;
    _failureCode = code;
    _logDiagnostic(method, code, details);
    notifyListeners();
  }

  void _logDiagnostic(String method, String code, [Object? details]) {
    final writer = diagnosticWriter;
    if (writer == null) return;
    _diagnosticTask = _diagnosticTask.then((_) async {
      var metadata = details;
      if (metadata is! Map) {
        try {
          metadata = await channel.invokeMethod<Object?>('getDiagnostics').timeout(const Duration(seconds: 1));
        } catch (_) {
          metadata = null;
        }
      }
      final safe = <String, Object?>{'method': method, 'code': code};
      if (metadata is Map) {
        if (metadata['ready'] case final bool ready) safe['ready'] = ready;
        if (metadata['win32Error'] case final int error) safe['win32Error'] = error;
        if (metadata['step'] case final String step
            when const ['not_attached', 'content_subclass', 'window_subclass', 'window_style', 'frame_change', 'ready'].contains(step)) {
          safe['step'] = step;
        }
      }
      try {
        await writer(safe);
      } catch (_) {
        // Diagnostics never change the window's success or failure.
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    channel.setMethodCallHandler(null);
    _backRequests.dispose();
    super.dispose();
  }
}
