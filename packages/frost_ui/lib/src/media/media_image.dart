import 'package:flutter/widgets.dart';

import '../primitives/_media_image_registry.dart';

/// Marks an actually displayed image inside a [FrostMediaCard].
/// Provider-mode FrostMediaFrame supplies this automatically. Custom image
/// loaders wrap only their decoded Image.frameBuilder branch, never loading,
/// error, unsupported content, or recovery controls. No pixels or loading state
/// are owned here, and outside a card this wrapper has no visual effect.
class FrostMediaImage extends StatefulWidget {
  const FrostMediaImage({required this.child, super.key});
  final Widget child;
  @override
  State<FrostMediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<FrostMediaImage> {
  FrostMediaImageRegistry? _registry;
  void _register() {
    final next = FrostMediaImageRegistryScope.maybeOf(context);
    if (identical(next, _registry)) return;
    _registry?.remove(this);
    _registry = next;
    next?.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void deactivate() {
    _registry?.remove(this);
    _registry = null;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    _register();
    return widget.child;
  }
}
