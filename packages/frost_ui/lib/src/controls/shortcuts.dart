import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Modifier names/symbols are fixed platform keyboard notation, not UI copy.
const _controlMarker = 'Ctrl', _shiftMarker = 'Shift', _altMarker = 'Alt', _keySeparator = '+';
const _appleAltMarker = '⌥', _appleShiftMarker = '⇧', _applePrimaryMarker = '⌘';
bool _apple(TargetPlatform platform) => platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;

/// A platform-independent key binding. Primary is Ctrl on Windows/Linux and
/// Meta on Apple platforms. Its display uses LogicalKeyboardKey.keyLabel.
@immutable
class FrostShortcut {
  const FrostShortcut(this.key, {this.primary = false, this.shift = false, this.alt = false});
  final LogicalKeyboardKey key;
  final bool primary, shift, alt;
  @override
  bool operator ==(Object other) => other is FrostShortcut && key == other.key && primary == other.primary && shift == other.shift && alt == other.alt;
  @override
  int get hashCode => Object.hash(key, primary, shift, alt);
}

/// Internal formatting shared by menus and their semantic hint.
String frostShortcutLabel(BuildContext context, FrostShortcut shortcut) {
  if (_apple(Theme.of(context).platform)) {
    return [if (shortcut.alt) _appleAltMarker, if (shortcut.shift) _appleShiftMarker, if (shortcut.primary) _applePrimaryMarker, shortcut.key.keyLabel].join();
  }
  return [if (shortcut.primary) _controlMarker, if (shortcut.shift) _shiftMarker, if (shortcut.alt) _altMarker, shortcut.key.keyLabel].join(_keySeparator);
}

class _InvokeShortcut extends Intent {
  const _InvokeShortcut(this.callback);
  final VoidCallback callback;
}

class _TextSafeActivator extends SingleActivator {
  _TextSafeActivator(this.shortcut, TargetPlatform platform)
    : super(shortcut.key, control: shortcut.primary && !_apple(platform), meta: shortcut.primary && _apple(platform), shift: shortcut.shift, alt: shortcut.alt);
  final FrostShortcut shortcut;
  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (!shortcut.primary && !shortcut.alt) {
      final context = FocusManager.instance.primaryFocus?.context;
      final editing = context?.widget is EditableText || context?.findAncestorWidgetOfExactType<EditableText>() != null;
      final character = event.character;
      final ordinary =
          shortcut.key.keyLabel.runes.length == 1 || (character != null && character.isNotEmpty && character.codeUnits.every((unit) => unit >= 32));
      if (editing && ordinary) return false;
    }
    return super.accepts(event, state);
  }
}

/// Registers bindings only while focus is within this widget's subtree.
/// Ordinary character shortcuts without Primary/Alt yield to text editors.
class FrostShortcuts extends StatelessWidget {
  const FrostShortcuts({required this.bindings, required this.child, super.key});
  final Map<FrostShortcut, VoidCallback> bindings;
  final Widget child;
  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: {for (final entry in bindings.entries) _TextSafeActivator(entry.key, Theme.of(context).platform): _InvokeShortcut(entry.value)},
    child: Actions(
      actions: {_InvokeShortcut: CallbackAction<_InvokeShortcut>(onInvoke: (intent) => intent.callback())},
      child: child,
    ),
  );
}

extension FrostShortcutX on Widget {
  /// Registers a shortcut for this component's focused subtree.
  Widget frostShortcut(FrostShortcut shortcut, VoidCallback onInvoke) => FrostShortcuts(bindings: {shortcut: onInvoke}, child: this);
}
