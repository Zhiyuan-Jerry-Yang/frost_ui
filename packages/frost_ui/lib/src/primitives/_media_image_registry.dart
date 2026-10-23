import 'package:flutter/widgets.dart';

/// Local ownership, like fields registered with a Form; never a global table.
/// Listeners drive render transforms, not ancestor widget rebuilds. This makes
/// registration during a child's build safe and removes scaling in the same
/// frame that the last displayed image becomes error/placeholder content.
class FrostMediaImageRegistry extends ChangeNotifier {
  final _images = <Object>{};
  bool _disposed = false;
  bool get hasImages => _images.isNotEmpty;
  void add(Object image) {
    if (_disposed || !_images.add(image)) return;
    if (_images.length == 1) notifyListeners();
  }

  void remove(Object image) {
    if (_disposed || !_images.remove(image)) return;
    if (_images.isEmpty) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _images.clear();
    super.dispose();
  }
}

class FrostMediaImageRegistryScope extends InheritedWidget {
  const FrostMediaImageRegistryScope({required this.registry, required super.child, super.key});
  final FrostMediaImageRegistry? registry;
  static FrostMediaImageRegistry? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMediaImageRegistryScope>()?.registry;
  @override
  bool updateShouldNotify(FrostMediaImageRegistryScope oldWidget) => registry != oldWidget.registry;
}

class FrostMediaImageHost extends StatefulWidget {
  const FrostMediaImageHost({required this.builder, super.key});
  final Widget Function(BuildContext context, FrostMediaImageRegistry registry) builder;
  @override
  State<FrostMediaImageHost> createState() => _ImageHostState();
}

class _ImageHostState extends State<FrostMediaImageHost> {
  final _registry = FrostMediaImageRegistry();
  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostMediaImageRegistryScope(registry: null, child: widget.builder(context, _registry));
}
