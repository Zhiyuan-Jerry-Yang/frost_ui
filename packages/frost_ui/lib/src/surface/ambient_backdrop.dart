import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../foundation/_ambient_material.dart';
import '../foundation/color_math.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../layout/window_caption_scope.dart';
import '../motion/_frame_work.dart';
import '_media_ambient.dart';
import '_window_background.dart';

// Bound full-window textures independently from the small decoded-art cache.
const _ambientTextureCapacity = 2;

class _AmbientFrame {
  _AmbientFrame(this.image, this.tokens, this.intensity, this.material, this.startWeight, {this.accentFallback = false});
  final ui.Image? image;
  final FrostThemeTokens tokens;
  final double intensity;
  final FrostAmbientMaterials? material;
  final bool accentFallback;
  double startWeight;
  ui.Image? texture;
  FrostFrameWork? preparation;
  int textureEpoch = 0;
  void dispose() {
    textureEpoch++;
    preparation?.cancel();
    texture?.dispose();
    image?.dispose();
  }
}

/// Window-wide ambient state shared by every [FrostAmbientBackdrop] painter.
///
/// The shell paints one backdrop behind the title bar and navigation, and a
/// route paints an identical one beneath itself while it animates. Both read
/// this controller and paint in window coordinates, so the page and the glass
/// around it always agree, including during the image cross-fade.
class FrostAmbientBackdropController extends ChangeNotifier {
  final _frames = <_AmbientFrame>[];
  final _material = ValueNotifier<FrostAmbientMaterials?>(null);
  double _progress = 1;
  Size _window = Size.zero;
  double _pixelRatio = 1;
  bool _disposed = false;
  bool _preparingTexture = false;

  void _resize(Size window, double pixelRatio) {
    if (_window == window && _pixelRatio == pixelRatio) return;
    _window = window;
    _pixelRatio = pixelRatio;
    for (final frame in _frames) {
      frame.textureEpoch++;
      frame.preparation?.cancel();
      frame.preparation = null;
      frame.texture?.dispose();
      frame.texture = null;
    }
    if (_frames.isNotEmpty) _prepareTexture(_frames.last);
    notifyListeners();
  }

  void _prepareTexture(_AmbientFrame frame) {
    if (_preparingTexture ||
        frame.texture != null ||
        _window.isEmpty ||
        !_window.isFinite ||
        frame.intensity == 0 ||
        frame.image == null && !frame.accentFallback) {
      return;
    }
    final epoch = ++frame.textureEpoch;
    final window = _window;
    final ratio = _pixelRatio;
    frame.preparation?.cancel();
    frame.preparation = FrostFrameWorkQueue.enqueue(() {
      frame.preparation = null;
      _preparingTexture = true;
      unawaited(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..scale(ratio, ratio);
        _RenderAmbient._paintEndpoint(canvas, frame, Offset.zero & window, Offset.zero & window);
        final picture = recorder.endRecording();
        ui.Image? texture;
        try {
          texture = await picture.toImage((window.width * ratio).ceil(), (window.height * ratio).ceil());
          if (_disposed || frame.textureEpoch != epoch || _frames.lastOrNull != frame) return;
          // Only two full-resolution endpoints are retained. Rapid retargeting
          // keeps the original live paint for older, fading endpoints instead
          // of growing a window-sized texture cache without a bound.
          final cached = _frames.where((f) => f.texture != null && f != frame).toList();
          for (final old in cached.take((cached.length + 1 - _ambientTextureCapacity).clamp(0, cached.length))) {
            old.texture?.dispose();
            old.texture = null;
          }
          frame.texture?.dispose();
          frame.texture = texture;
          texture = null;
          notifyListeners();
        } catch (error, stack) {
          if (!_disposed && frame.textureEpoch == epoch) {
            FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient endpoint preparation'));
          }
        } finally {
          texture?.dispose();
          picture.dispose();
          _preparingTexture = false;
          // Native preparation cannot be cancelled. Keep at most one in flight,
          // then prepare the latest retarget instead of accumulating old work.
          if (!_disposed && frame.textureEpoch != epoch && _frames.isNotEmpty) _prepareTexture(_frames.last);
        }
      }());
    });
  }

  ui.Image? get current => _frames.lastOrNull?.image;
  ui.Image? get previous => _frames.length < 2 ? null : _frames.first.image;
  double get progress => _progress;
  double _weight(int index) => index == _frames.length - 1 ? _progress : _frames[index].startWeight * (1 - _progress);

  void _show(ui.Image? image, FrostThemeTokens tokens, double intensity, FrostAmbientMaterials? material, {required bool accentFallback}) {
    for (var index = 0; index < _frames.length; index++) {
      _frames[index].startWeight = _weight(index);
    }
    _frames.removeWhere((frame) {
      if (frame.startWeight > 0) return false;
      frame.dispose();
      return true;
    });
    if (_frames.isEmpty) _frames.add(_AmbientFrame(null, tokens, 0, null, 1));
    for (final frame in _frames) {
      frame.textureEpoch++;
      frame.preparation?.cancel();
      frame.preparation = null;
    }
    final target = _AmbientFrame(image, tokens, intensity, material, 0, accentFallback: accentFallback);
    _frames.add(target);
    _prepareTexture(target);
    _progress = 0;
    _publishMaterial();
    notifyListeners();
  }

  void _publishMaterial() {
    final active = _frames.where((f) => f.material != null && f.intensity > 0).toList();
    if (active.isEmpty) {
      _material.value = null;
      return;
    }
    final dark = _frames.last.tokens.isDark;
    var background = active.first.material!.background;
    for (final frame in active.skip(1)) {
      final other = frame.material!.background;
      double bound(double a, double b) => dark ? (a > b ? a : b) : (a < b ? a : b);
      background = Color.from(alpha: 1, red: bound(background.r, other.r), green: bound(background.g, other.g), blue: bound(background.b, other.b));
    }
    _material.value = FrostAmbientMaterials(mask: _frames.last.material?.mask ?? 0, background: background);
  }

  void _setProgress(double value) {
    if (_progress == value) return;
    _progress = value;
    if (value >= 1 && _frames.length > 1) {
      for (final frame in _frames.take(_frames.length - 1)) {
        frame.dispose();
      }
      final last = _frames.last;
      _frames
        ..clear()
        ..add(last);
      _publishMaterial();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final frame in _frames) {
      frame.dispose();
    }
    _material.dispose();
    super.dispose();
  }
}

class _AmbientScope extends InheritedWidget {
  const _AmbientScope({required this.controller, required this.forceSolid, required super.child});

  final FrostAmbientBackdropController controller;
  final bool forceSolid;

  @override
  bool updateShouldNotify(_AmbientScope oldWidget) => !identical(controller, oldWidget.controller) || forceSolid != oldWidget.forceSolid;
}

/// Optional artwork-free ambient paint. None preserves native Mica visibility.
enum FrostAmbientFallback { none, accentWash }

/// Owns the ambient state for the window and paints it behind [child].
///
/// [image] is the current page's artwork, if any. Supply a provider that
/// decodes at about [sampleWidth] pixels wide; it is pre-blurred once, so
/// the complete window endpoint (artwork, washes and scrim) is then prepared at
/// the view's physical resolution. Moving pages composite that texture instead
/// of re-running gradients and color filters. At most two endpoints are retained.
/// Providers are cached by equality, so equal providers
/// for the same picture reuse the blurred copy. A replacement keeps the last
/// usable artwork while loading and after failure; only an explicit null clears
/// artwork. Late results from earlier replacements are discarded.
class FrostAmbientBackdropHost extends StatefulWidget {
  const FrostAmbientBackdropHost({required this.image, required this.child, this.intensity = 1, this.fallback = FrostAmbientFallback.none, super.key})
    : assert(intensity >= 0 && intensity <= 1);

  /// Artwork and accent-wash contribution. One preserves the original paint;
  /// zero paints a solid canvas even when system Mica is available.
  /// Changes cross-fade cached paint states; they never re-decode the artwork.
  /// A contrast-only canvas scrim is derived from the full-strength blurred
  /// sample and kept fixed across intensity values. Lower values therefore
  /// approach the solid canvas without a weaker scrim cancelling the change.
  final double intensity;

  /// None keeps the existing no-image canvas/Mica behaviour. AccentWash uses
  /// the existing two accent washes when no artwork is available, with the
  /// same intensity and contrast solver. Zero intensity is always solid.
  /// This option has no effect while artwork is present.
  final FrostAmbientFallback fallback;

  /// Decode width the blurred backdrop needs; larger decodes are wasted.
  static const sampleWidth = 48;

  final ImageProvider? image;
  final Widget child;

  @override
  State<FrostAmbientBackdropHost> createState() => _FrostAmbientBackdropHostState();
}

class _FrostAmbientBackdropHostState extends State<FrostAmbientBackdropHost> with SingleTickerProviderStateMixin {
  static const _sampleWidth = FrostAmbientBackdropHost.sampleWidth;
  final _controller = FrostAmbientBackdropController();
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))
    ..addListener(() => _controller._setProgress(Curves.easeInOut.transform(_fade.value)));
  final Map<ImageProvider, ({ui.Image image, FrostAmbientSample sample})> _blurred = {};
  FrostAmbientSample? _sample;
  FrostThemeTokens? _tokens;
  double _aspect = 1;
  Object? _appearanceKey;
  ImageProvider? _requested;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = FrostThemeTokens.of(context);
    _tokens = context.dependOnInheritedWidgetOfExactType<FrostAmbientThemeScope>()?.tokens ?? raw;
    final size = MediaQuery.sizeOf(context);
    _aspect = size.width / size.height;
    final view = View.of(context);
    // Retarget first so entering Black cancels old endpoint preparation before
    // a simultaneous resize can schedule an unused full-window texture.
    _request(_tokens!.isBlack ? null : widget.image);
    _refreshAppearance();
    _controller._resize(view.physicalSize / view.devicePixelRatio, view.devicePixelRatio);
  }

  @override
  void didUpdateWidget(FrostAmbientBackdropHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _request(_tokens!.isBlack ? null : widget.image);
    if (oldWidget.intensity != widget.intensity || oldWidget.fallback != widget.fallback) _refreshAppearance();
  }

  void _request(ImageProvider? provider) {
    if (provider == _requested) return;
    _requested = provider;
    _detachStream();
    if (provider == null) {
      _present(null);
      return;
    }
    if (_blurred[provider] case final cached?) {
      _present(cached.image.clone(), cached.sample);
      return;
    }
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted || _requested != provider) {
          info.dispose();
          return;
        }
        _detachStream();
        unawaited(_prepareArtwork(provider, info));
      },
      onError: (_, _) {
        if (!mounted || _requested != provider) return;
        _detachStream();
        if (_controller.current == null && _controller.previous == null) {
          _present(null);
        }
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Future<void> _prepareArtwork(ImageProvider provider, ImageInfo info) async {
    ui.Image? image;
    try {
      image = await _blur(info.image);
      if (!mounted || _requested != provider) return;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (bytes == null || !mounted || _requested != provider) return;
      final pixels = <Color>[];
      for (var offset = 0; offset < bytes.lengthInBytes; offset += 4) {
        // Transparent source pixels reveal the canvas, not opaque black.
        pixels.add(Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2)));
      }
      _accept(provider, image, FrostAmbientSample(image.width, image.height, pixels));
      image = null; // The cache owns this handle after acceptance.
    } catch (error, stack) {
      if (mounted && _requested == provider) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'ambient artwork'));
      }
    } finally {
      image?.dispose();
      info.dispose();
    }
  }

  void _detachStream() {
    if (_listener case final listener?) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  static Future<ui.Image> _blur(ui.Image source) {
    final width = _sampleWidth;
    final height = (width * source.height / source.width).round().clamp(8, 96);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    // Clamp the edges so the blur does not fade to transparent at the border.
    canvas.saveLayer(bounds, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3, tileMode: TileMode.clamp));
    canvas.drawImageRect(source, Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()), bounds, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
    final picture = recorder.endRecording();
    return picture.toImage(width, height).whenComplete(picture.dispose);
  }

  void _accept(ImageProvider provider, ui.Image image, FrostAmbientSample sample) {
    if (!mounted) {
      image.dispose();
      return;
    }
    if (_blurred.length >= frostAmbientCacheCapacity) _blurred.remove(_blurred.keys.first)?.image.dispose();
    _blurred[provider] = (image: image, sample: sample);
    if (_requested == provider) _present(image.clone(), sample);
  }

  void _present(ui.Image? image, [FrostAmbientSample? sample]) {
    if (image == null && _controller.current == null && _controller.previous == null && widget.fallback == FrostAmbientFallback.none) return;
    _sample = sample;
    _appearanceKey = null;
    _animate(image, sample, imageChange: true);
  }

  void _refreshAppearance() {
    if (_controller.current == null && _controller._frames.isEmpty && widget.fallback == FrostAmbientFallback.none) return;
    final tokens = _tokens!;
    final key = (
      tokens.brightness,
      tokens.tone,
      tokens.canvas,
      tokens.surface,
      tokens.textPrimary,
      tokens.textSecondary,
      tokens.accent,
      widget.intensity,
      widget.fallback,
      _aspect,
    );
    if (key == _appearanceKey) return;
    _appearanceKey = key;
    _animate(_controller.current?.clone(), _sample, imageChange: false);
  }

  void _animate(ui.Image? image, FrostAmbientSample? sample, {required bool imageChange}) {
    final tokens = _tokens!;
    _appearanceKey = (
      tokens.brightness,
      tokens.tone,
      tokens.canvas,
      tokens.surface,
      tokens.textPrimary,
      tokens.textSecondary,
      tokens.accent,
      widget.intensity,
      widget.fallback,
      _aspect,
    );
    final accentFallback = !tokens.isBlack && widget.fallback == FrostAmbientFallback.accentWash;
    final material =
        sample?.resolve(tokens, widget.intensity, _aspect) ?? (accentFallback ? frostAmbientAccentMaterial(tokens, widget.intensity, _aspect) : null);
    _controller._show(image, tokens, widget.intensity, material, accentFallback: accentFallback);
    _fade.duration = imageChange ? const Duration(milliseconds: 420) : FrostMotion.hover;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller._setProgress(1);
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _detachStream();
    _fade.dispose();
    _controller.dispose();
    for (final image in _blurred.values) {
      image.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller._material,
      child: widget.child,
      builder: (context, child) => FrostWindowBackgroundScope(
        hasAmbient: _controller._material.value != null,
        forceSolidBase: widget.intensity == 0,
        background: _controller._material.value?.background,
        child: _AmbientScope(
          controller: _controller,
          forceSolid: widget.intensity == 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const RepaintBoundary(child: FrostAmbientBackdrop()),
              child!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints the window's ambient backdrop, aligned to the window rather than to
/// this widget. Use it wherever the ambient layer has to be opaque locally,
/// such as beneath a route while its transition overlaps the previous page.
class FrostAmbientBackdrop extends StatelessWidget {
  const FrostAmbientBackdrop({super.key}) : _media = null;

  /// Blurs app-owned media behind a surface scrim. Reduced transparency uses
  /// a cached 16 by 16 average, composited with the same opaque surface scrim.
  const FrostAmbientBackdrop.fromImage({required ImageProvider image, required Widget child, super.key}) : _media = (image: image, child: child);
  final ({ImageProvider image, Widget child})? _media;

  @override
  Widget build(BuildContext context) {
    if (_media case final media?) {
      return FrostMediaAmbientBackdrop(image: media.image, child: media.child);
    }
    final tokens = FrostThemeTokens.of(context);
    final plain = tokens.isBlack || FrostScope.solidSurfaces(context);
    final scope = context.dependOnInheritedWidgetOfExactType<_AmbientScope>();
    final controller = scope?.controller;
    // No repaint boundary here: the backdrop is window-aligned, so it has to
    // repaint when an ancestor transition moves it.
    return _AmbientPaint(
      controller: plain ? null : controller,
      tokens: tokens,
      plain: plain,
      systemBackdrop: !plain && !(scope?.forceSolid ?? false) && FrostWindowCaptionScope.systemBackdropActiveOf(context),
    );
  }
}

class _AmbientPaint extends LeafRenderObjectWidget {
  const _AmbientPaint({required this.controller, required this.tokens, required this.plain, required this.systemBackdrop});

  final FrostAmbientBackdropController? controller;
  final FrostThemeTokens tokens;
  final bool plain;
  final bool systemBackdrop;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAmbient(controller: controller, tokens: tokens, plain: plain, systemBackdrop: systemBackdrop);

  @override
  void updateRenderObject(BuildContext context, _RenderAmbient renderObject) {
    renderObject
      ..controller = controller
      ..tokens = tokens
      ..plain = plain
      ..systemBackdrop = systemBackdrop;
  }
}

class _RenderAmbient extends RenderBox {
  _RenderAmbient({required FrostAmbientBackdropController? controller, required FrostThemeTokens tokens, required bool plain, required bool systemBackdrop})
    : this._(controller, tokens, plain, systemBackdrop);
  _RenderAmbient._(this._controller, this._tokens, this._plain, this._systemBackdrop);

  FrostAmbientBackdropController? _controller;
  set controller(FrostAmbientBackdropController? value) {
    if (identical(value, _controller)) return;
    if (attached) {
      _controller?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _controller = value;
    markNeedsPaint();
  }

  FrostThemeTokens _tokens;
  set tokens(FrostThemeTokens value) {
    if (value == _tokens) return;
    _tokens = value;
    markNeedsPaint();
  }

  bool _plain;
  set plain(bool value) {
    if (value == _plain) return;
    _plain = value;
    markNeedsPaint();
  }

  bool _systemBackdrop;
  set systemBackdrop(bool value) {
    if (_systemBackdrop == value) return;
    _systemBackdrop = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _controller?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final local = offset & size;
    // An absent/failed ambient image reveals Mica when actually available.
    // Opaque fallbacks remain entirely app-owned on every other platform.
    final hasAccentFallback = _controller?._frames.any((frame) => frame.accentFallback && frame.intensity > 0) ?? false;
    if (!_plain && _systemBackdrop && !hasAccentFallback && _controller?.current == null && _controller?.previous == null) return;
    if (_plain || _controller == null || _controller!._frames.isEmpty) {
      canvas.drawRect(local, Paint()..color = _tokens.canvas);
      return;
    }
    final view = ui.PlatformDispatcher.instance.implicitView;
    final window = view == null ? size : view.physicalSize / view.devicePixelRatio;
    final toWindow = Matrix4.tryInvert(getTransformTo(null));
    final windowRect = toWindow == null
        ? (offset - localToGlobal(Offset.zero)) & window
        : MatrixUtils.transformRect(toWindow, Offset.zero & window).shift(offset);
    final frames = _controller!._frames;
    final visible = <(int, double)>[];
    var total = 0.0;
    for (var index = 0; index < frames.length; index++) {
      final weight = _controller!._weight(index);
      if (weight <= 0 || (_systemBackdrop && frames[index].image == null && !frames[index].accentFallback)) continue;
      visible.add((index, weight));
      total += weight;
    }
    if (total == 0) return;
    final opacity = total.clamp(0.0, 1.0);
    // A complete endpoint is opaque. Do not allocate a window-sized opacity
    // buffer for alpha one on every moving-page frame.
    if (opacity < 1) {
      canvas.saveLayer(local, Paint()..color = _tokens.canvas.withValues(alpha: opacity));
    } else {
      canvas.save();
    }
    canvas.clipRect(local);
    var accumulated = 0.0;
    for (final (index, weight) in visible) {
      final frame = frames[index];
      accumulated += weight;
      // Blend complete, already-readable endpoints. Retargeting retains the
      // current weighted picture instead of jumping to the old target.
      final blend = weight / accumulated;
      if (blend < 1) canvas.saveLayer(local, Paint()..color = _tokens.canvas.withValues(alpha: blend));
      if (frame.texture case final texture?) {
        canvas.drawRect(local, Paint()..color = frame.tokens.canvas);
        canvas.drawImageRect(
          texture,
          Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
          windowRect,
          Paint()..filterQuality = FilterQuality.medium,
        );
      } else {
        _paintEndpoint(canvas, frame, local, windowRect);
      }
      if (blend < 1) canvas.restore();
    }
    canvas.restore();
  }

  static void _paintEndpoint(Canvas canvas, _AmbientFrame frame, Rect local, Rect windowRect) {
    canvas.drawRect(local, Paint()..color = frame.tokens.canvas);
    if (frame.image case final artwork? when frame.intensity > 0) {
      final opacity = frame.intensity * (frame.tokens.isDark ? frostAmbientDarkArtworkOpacity : frostAmbientLightArtworkOpacity);
      _paintArtwork(canvas, artwork, windowRect, opacity);
    }
    if (frame.intensity > 0 && (frame.image != null || frame.accentFallback)) {
      _paintWashes(canvas, local, windowRect, frame.tokens, frame.intensity);
      canvas.drawRect(local, Paint()..color = frame.tokens.canvas.withValues(alpha: frame.material!.mask));
    }
  }

  static void _paintWashes(Canvas canvas, Rect local, Rect windowRect, FrostThemeTokens tokens, double intensity) {
    final wash = ambientAccent(tokens.accent);
    final extent = windowRect.longestSide;
    canvas.drawRect(
      local,
      Paint()
        ..shader = RadialGradient(
          colors: [
            wash.withValues(alpha: (tokens.isDark ? .16 : .12) * intensity),
            wash.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: windowRect.topLeft + Offset(windowRect.width * .12, 0), radius: extent * .62)),
    );
    final counter = HSLColor.fromColor(wash);
    canvas.drawRect(
      local,
      Paint()
        ..shader = RadialGradient(
          colors: [
            counter.withHue((counter.hue + 38) % 360).toColor().withValues(alpha: (tokens.isDark ? .10 : .08) * intensity),
            counter.toColor().withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: windowRect.bottomRight, radius: extent * .55)),
    );
  }

  static void _paintArtwork(Canvas canvas, ui.Image image, Rect windowRect, double opacity) {
    if (opacity <= 0) return;
    final source = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, source.size, windowRect.size);
    final destination = Alignment.center.inscribe(fitted.destination, windowRect);
    canvas.drawImageRect(
      image,
      Alignment.center.inscribe(fitted.source, source),
      destination,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = const ColorFilter.matrix(_desaturate)
        ..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }

  // Saturation .7 is shared with the cached sample analysis.
  static const _desaturate = frostAmbientSaturationMatrix;
}
