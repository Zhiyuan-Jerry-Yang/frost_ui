import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../foundation/_media_contrast.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';

// Match the existing window-ambient cache's bounded capacity.
const frostAmbientCacheCapacity = 12;
// Media backdrops use a strong blur and theme-dependent surface scrim.
const _mediaBlurSigma = 80.0;
// Derived textures stay small; sigma is scaled independently on each axis so
// the displayed blur remains eighty logical pixels at every viewport size.
const _mediaBlurSampleWidth = 48;
const _mediaBlurMinSampleHeight = 8;
const _mediaBlurMaxSampleHeight = 128;
// A small square decode is sufficient for an alpha-weighted average.
const _averageSampleExtent = 16;
final _averageColors = <ImageProvider, Future<Color>>{};

Future<Color> _averageColor(ImageProvider provider, ImageConfiguration configuration) {
  if (_averageColors[provider] case final cached?) return cached;
  if (_averageColors.length >= frostAmbientCacheCapacity) _averageColors.remove(_averageColors.keys.first);
  final future = _decodeAverage(provider, configuration);
  _averageColors[provider] = future;
  return future;
}

Future<Color> _decodeAverage(ImageProvider provider, ImageConfiguration configuration) {
  final completion = Completer<Color>();
  final resized = ResizeImage.resizeIfNeeded(_averageSampleExtent, _averageSampleExtent, provider);
  final stream = resized.resolve(configuration);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      unawaited(() async {
        try {
          final bytes = await info.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
          if (bytes == null) throw StateError('Image pixels are unavailable.');
          var red = 0.0, green = 0.0, blue = 0.0, alpha = 0.0;
          final count = info.image.width * info.image.height;
          for (var i = 0; i < bytes.lengthInBytes; i += 4) {
            final a = bytes.getUint8(i + 3).toDouble();
            alpha += a;
            red += bytes.getUint8(i) * a;
            green += bytes.getUint8(i + 1) * a;
            blue += bytes.getUint8(i + 2) * a;
          }
          completion.complete(
            alpha == 0 ? Colors.transparent : Color.fromARGB((alpha / count).round(), (red / alpha).round(), (green / alpha).round(), (blue / alpha).round()),
          );
        } catch (error, stack) {
          completion.completeError(error, stack);
        } finally {
          info.dispose();
        }
      }());
    },
    onError: (Object error, StackTrace? stack) {
      stream.removeListener(listener);
      if (!completion.isCompleted) completion.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return completion.future;
}

/// Private media mode; the public ambient painter retains its window contract.
class FrostMediaAmbientBackdrop extends StatelessWidget {
  const FrostMediaAmbientBackdrop({required this.image, required this.child, super.key});
  final ImageProvider image;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) => _SizedMediaAmbientBackdrop(image: image, size: constraints.biggest, child: child),
  );
}

class _SizedMediaAmbientBackdrop extends StatefulWidget {
  const _SizedMediaAmbientBackdrop({required this.image, required this.size, required this.child});
  final ImageProvider image;
  final Size size;
  final Widget child;
  @override
  State<_SizedMediaAmbientBackdrop> createState() => _FrostMediaAmbientBackdropState();
}

class _FrostMediaAmbientBackdropState extends State<_SizedMediaAmbientBackdrop> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: FrostMotion.reveal, value: 1, animationBehavior: AnimationBehavior.preserve)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _previous?.dispose();
        _previous = null;
      }
    });
  ({ImageProvider image, Size size})? _requested;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _current, _previous;
  Future<Color>? _average;
  ImageProvider? _averageProvider;
  bool _solid = false, _black = false;
  int _requestEpoch = 0, _frameEpoch = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _solid = FrostScope.solidSurfaces(context);
    _black = FrostThemeTokens.of(context).isBlack;
    _request();
  }

  @override
  void didUpdateWidget(_SizedMediaAmbientBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _request();
  }

  void _request() {
    if (_black || widget.size.isEmpty || !widget.size.isFinite) {
      _detach();
      _requested = null;
      return;
    }
    if (_solid) {
      _detach();
      _requested = null;
      if (_averageProvider != widget.image) {
        _averageProvider = widget.image;
        _average = _averageColor(widget.image, createLocalImageConfiguration(context));
      }
      return;
    }
    final key = (image: widget.image, size: widget.size);
    if (_requested == key) return;
    _detach();
    _requested = key;
    final provider = widget.image;
    final epoch = _requestEpoch;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!mounted || epoch != _requestEpoch || _requested != key) {
          info.dispose();
          return;
        }
        unawaited(_prepareFrame(info, epoch, ++_frameEpoch, key));
      },
      onError: (_, _) {
        if (mounted && epoch == _requestEpoch) _detach();
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Future<void> _prepareFrame(ImageInfo info, int epoch, int frame, ({ImageProvider image, Size size}) key) async {
    ui.Image? blurred;
    try {
      blurred = await _blur(info.image, key.size);
      if (!mounted || epoch != _requestEpoch || frame != _frameEpoch || _requested != key) return;
      final ready = blurred;
      blurred = null;
      setState(() {
        _previous?.dispose();
        _previous = _current;
        _current = ready;
      });
      _fade.duration = MediaQuery.disableAnimationsOf(context) ? FrostMotion.reducedFade : FrostMotion.reveal;
      _fade.forward(from: 0);
    } catch (error, stack) {
      if (mounted && epoch == _requestEpoch) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'media ambient backdrop'));
      }
    } finally {
      blurred?.dispose();
      info.dispose();
    }
  }

  static Future<ui.Image> _blur(ui.Image source, Size target) {
    final width = _mediaBlurSampleWidth;
    final height = (width * target.height / target.width).round().clamp(_mediaBlurMinSampleHeight, _mediaBlurMaxSampleHeight);
    final fitted = applyBoxFit(BoxFit.cover, Size(source.width.toDouble(), source.height.toDouble()), target);
    final sourceRect = Alignment.center.inscribe(fitted.source, Offset.zero & Size(source.width.toDouble(), source.height.toDouble()));
    final destination = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.saveLayer(
      destination,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _mediaBlurSigma * width / target.width,
          sigmaY: _mediaBlurSigma * height / target.height,
          tileMode: TileMode.clamp,
        ),
    );
    canvas.drawImageRect(source, sourceRect, destination, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
    final picture = recorder.endRecording();
    return picture.toImage(width, height).whenComplete(picture.dispose);
  }

  void _detach() {
    _requestEpoch++;
    if (_listener case final listener?) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    _fade.dispose();
    _current?.dispose();
    _previous?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final scrim = frostMediaScrimOpacity(tokens);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Only the background is clipped; foreground focus and paint remain
        // independent from its preprocessed texture.
        ClipRect(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: _black
                  ? const ColoredBox(color: Colors.black)
                  : _solid
                  ? FutureBuilder<Color>(
                      future: _average,
                      builder: (context, snapshot) {
                        final average = Color.alphaBlend(snapshot.data ?? tokens.surface, tokens.surface);
                        final color = Color.alphaBlend(tokens.surface.withValues(alpha: scrim), average).withValues(alpha: 1);
                        return TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: color),
                          duration: MediaQuery.disableAnimationsOf(context) ? FrostMotion.reducedFade : FrostMotion.reveal,
                          builder: (_, color, _) => ColoredBox(color: color!),
                        );
                      },
                    )
                  : ColoredBox(
                      color: tokens.surface,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Both images are already cover-cropped and blurred. A moving
                          // page crossfades two small textures, never a full-screen filter.
                          AnimatedBuilder(
                            animation: _fade,
                            builder: (context, _) => Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_previous case final previous?)
                                  Opacity(
                                    opacity: 1 - _fade.value,
                                    child: RawImage(image: previous, fit: BoxFit.fill),
                                  ),
                                if (_current case final current?)
                                  Opacity(
                                    opacity: _fade.value,
                                    child: RawImage(image: current, fit: BoxFit.fill),
                                  ),
                              ],
                            ),
                          ),
                          ColoredBox(color: tokens.surface.withValues(alpha: scrim)),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
