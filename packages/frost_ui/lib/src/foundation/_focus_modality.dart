import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Framework traditional mode combines mouse and keyboard. Frost outlines
/// distinguish them without changing focus ownership or global highlight policy.
/// Subscriptions exist only while shared interactive surfaces are mounted.
class FrostInputModality extends ChangeNotifier {
  static final instance = FrostInputModality._();
  FrostInputModality._();
  var _clients = 0;
  bool keyboard = true;
  PointerDeviceKind? _pointerKind;
  bool get touch => _pointerKind == PointerDeviceKind.touch;

  // Layout can synthesize mouse enter events while a stationary mouse remains
  // over content. Only real pointer movement may restore hover after touch.
  bool acceptsHover(PointerEvent event) => event.kind != PointerDeviceKind.touch && (!touch || event is PointerHoverEvent);
  void attach() {
    if (_clients++ != 0) return;
    keyboard = true;
    _pointerKind = null;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
    HardwareKeyboard.instance.addHandler(_key);
  }

  void detach() {
    assert(_clients > 0);
    if (--_clients != 0) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
    HardwareKeyboard.instance.removeHandler(_key);
    keyboard = true;
    _pointerKind = null;
  }

  void _set(bool value, [PointerDeviceKind? kind]) {
    if (value == keyboard && kind == _pointerKind) return;
    keyboard = value;
    _pointerKind = kind;
    notifyListeners();
  }

  void _pointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerHoverEvent && event.kind != PointerDeviceKind.touch) {
      _set(false, event.kind);
    }
  }

  bool _key(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) _set(true);
    return false;
  }
}
