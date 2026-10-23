import 'package:flutter/foundation.dart';

/// Internal layout-to-paint notification. It never rebuilds a widget or repairs
/// geometry after layout; the first layout establishes its identity silently.
class FrostLayoutIdentity extends ChangeNotifier {
  Object? _identity, _viewport;
  bool identityChanged = false;

  void update(Object identity, {required Object viewport}) {
    if (_identity == identity && _viewport == viewport) return;
    final initial = _identity == null;
    identityChanged = _identity != identity;
    _identity = identity;
    _viewport = viewport;
    if (!initial) notifyListeners();
  }
}
