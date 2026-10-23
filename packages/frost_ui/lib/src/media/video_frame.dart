import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/_dynamic_icon_button.dart';
import '../controls/_slider_media_scope.dart';
import '../controls/buttons.dart';
import '../controls/shortcuts.dart';
import '../controls/slider.dart';
import '../feedback/activity_indicator.dart';
import '../feedback/loading_gate.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../primitives/_presence_material.dart';
import '../primitives/icon.dart';
import '../primitives/presence.dart';
import '_video_bar.dart';
import 'video_state.dart';

// Playback clocks and keyboard seek use whole seconds; drag precision remains
// in microseconds and the application alone changes the actual player.
const _videoIdleDelay = Duration(milliseconds: 2500);
const _videoSeekStep = Duration(seconds: 5);
const _secondsPerMinute = 60;
const _secondsPerHour = _secondsPerMinute * _secondsPerMinute;
const _microsecondsPerSecond = Duration.microsecondsPerSecond;
const _clockSeparator = ':';
const _clockZero = '0';

/// Player-free media controls. Give the frame finite width and height; [video]
/// owns decoding, fitting and playback. Only releasing a seek calls [onSeek].
/// Playback time, its slider and arrow shortcuts stay LTR even in RTL content.
class FrostVideoFrame extends StatefulWidget {
  const FrostVideoFrame({
    required this.video,
    required this.state,
    required this.onPlayPause,
    required this.onSeek,
    this.onMuteToggle,
    this.onLoopToggle,
    this.onFullscreenToggle,
    super.key,
  });
  final Widget video;
  final FrostVideoState state;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;

  /// Optional loop toggle. Its selected and toggled semantics follow [state].
  final VoidCallback? onLoopToggle;

  /// No callback leaves an empty compact slot, without focus or semantics, so
  /// discovering an audio track never moves the loop or fullscreen controls.
  final VoidCallback? onMuteToggle;
  final VoidCallback? onFullscreenToggle;

  @override
  State<FrostVideoFrame> createState() => _VideoFrameState();
}

class _VideoFrameState extends State<FrostVideoFrame> {
  final _focus = FocusNode(), _barFocus = FocusScopeNode();
  Timer? _idle;
  bool _visible = true, _dragging = false, _barHover = false;
  double? _preview;
  bool get _enabled => FrostControlScope.enabledOf(context);
  double get _duration => math.max(0, widget.state.duration.inMicroseconds / _microsecondsPerSecond);
  double get _position => (widget.state.position.inMicroseconds / _microsecondsPerSecond).clamp(0.0, _duration);
  double get _buffered => (widget.state.buffered.inMicroseconds / _microsecondsPerSecond).clamp(0.0, _duration);
  bool get _keepVisible => !widget.state.playing || widget.state.buffering || _dragging || _barHover || _barFocus.hasFocus;
  void _schedule() {
    _idle?.cancel();
    if (_keepVisible || !_visible) return;
    _idle = Timer(_videoIdleDelay, () {
      if (mounted && !_keepVisible) setState(() => _visible = false);
    });
  }

  void _activity() {
    if (!mounted) return;
    if (!_visible) setState(() => _visible = true);
    _schedule();
  }

  void _toggleControls() {
    _focus.requestFocus();
    if (_keepVisible) {
      _activity();
      return;
    }
    setState(() => _visible = !_visible);
    _schedule();
  }

  void _invoke(VoidCallback? callback) {
    if (!_enabled || callback == null) return;
    _activity();
    callback();
  }

  void _seek(double seconds) {
    if (!_enabled || _duration <= 0) return;
    final target = seconds.clamp(0.0, _duration);
    setState(() => _preview = null);
    _activity();
    widget.onSeek(Duration(microseconds: (target * _microsecondsPerSecond).round()));
  }

  void _interaction(bool active) {
    setState(() {
      _dragging = active;
      if (!active) _preview = null;
    });
    _activity();
  }

  String _clock(double value) {
    final seconds = math.max(0, value.floor());
    final minutes = seconds ~/ _secondsPerMinute, tail = (seconds % _secondsPerMinute).toString().padLeft(2, _clockZero);
    if (seconds < _secondsPerHour) return '$minutes$_clockSeparator$tail';
    final hours = seconds ~/ _secondsPerHour, minute = (minutes % _secondsPerMinute).toString().padLeft(2, _clockZero);
    return '$hours$_clockSeparator$minute$_clockSeparator$tail';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) {
      _dragging = false;
      _preview = null;
    }
    _schedule();
  }

  @override
  void didUpdateWidget(FrostVideoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cancelledDrag = _dragging && _duration == 0;
    if (_duration == 0) {
      _dragging = false;
      _preview = null;
    }
    // Player clock updates must not restart the pointer's idle countdown.
    if (oldWidget.state.playing != widget.state.playing || oldWidget.state.buffering != widget.state.buffering || cancelledDrag) {
      if (_keepVisible) _visible = true;
      _schedule();
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    _focus.dispose();
    _barFocus.dispose();
    super.dispose();
  }

  Widget _button(FrostIconData icon, String label, VoidCallback? action, {FrostControlSize size = FrostControlSize.compact}) => FrostDynamicIconButton(
    label: label,
    media: true,
    size: size,
    onPressed: _enabled && action != null ? () => _invoke(action) : null,
    icon: FrostIcon(icon, key: ValueKey(icon)),
  );
  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context), icons = FrostIconSet.of(context), tokens = FrostThemeTokens.of(context);
    final current = _preview ?? _position;
    final play = _button(widget.state.playing ? icons.pause : icons.play, widget.state.playing ? labels.pause : labels.play, widget.onPlayPause);
    final slider = Directionality(
      textDirection: TextDirection.ltr,
      child: FrostSliderMediaScope(
        ink: tokens.onMediaInk,
        buffered: _duration == 0 ? 0 : _buffered / _duration,
        step: _videoSeekStep.inSeconds.toDouble(),
        onInteractionChanged: _interaction,
        child: FrostSlider(
          value: current,
          max: math.max(1, _duration),
          semanticLabel: labels.seek,
          valueLabel: _clock,
          onChanged: _enabled && _duration > 0 ? (value) => setState(() => _preview = value) : null,
          onChangeEnd: _seek,
        ),
      ),
    );
    Widget frame = Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) _activity();
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => _activity(),
        onHover: (_) => _activity(),
        onExit: (_) => _schedule(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggleControls, child: widget.video),
            Center(
              child: FrostLoadingGate(
                loading: widget.state.buffering,
                builder: (context, buffering) => Stack(
                  alignment: Alignment.center,
                  children: [
                    FrostPresence(
                      visible: buffering,
                      child: IgnorePointer(
                        child: FrostActivityForeground(
                          color: tokens.onMediaInk,
                          child: FrostActivityIndicator(size: FrostControlSize.large, semanticLabel: labels.loading),
                        ),
                      ),
                    ),
                    FrostPresence(
                      visible: !widget.state.playing && !widget.state.buffering && !buffering,
                      child: _button(icons.play, labels.play, () {
                        _focus.requestFocus();
                        widget.onPlayPause();
                      }, size: FrostControlSize.large),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FrostPresenceMaterial(
                child: FrostPresence(
                  visible: _visible,
                  child: FocusScope(
                    node: _barFocus,
                    onFocusChange: (_) => _activity(),
                    child: MouseRegion(
                      onEnter: (_) {
                        setState(() => _barHover = true);
                        _activity();
                      },
                      onExit: (_) {
                        setState(() => _barHover = false);
                        _schedule();
                      },
                      child: FrostVideoBar(
                        play: play,
                        current: _clock(current),
                        total: _clock(_duration),
                        slider: slider,
                        trailing: [
                          if (widget.onLoopToggle != null)
                            FrostButton.icon(
                              icon: icons.repeat,
                              label: labels.loop,
                              style: FrostIconButtonStyle.onMedia,
                              size: FrostControlSize.compact,
                              selected: widget.state.looping,
                              onPressed: _enabled ? () => _invoke(widget.onLoopToggle) : null,
                            ),
                          if (widget.onMuteToggle != null)
                            _button(
                              widget.state.muted ? icons.volumeOff : icons.volumeOn,
                              widget.state.muted ? labels.unmute : labels.mute,
                              widget.onMuteToggle,
                            )
                          else
                            SizedBox.square(dimension: FrostDensity.of(context).targetHeight),
                          if (widget.onFullscreenToggle != null)
                            _button(
                              widget.state.fullscreen ? icons.exitFullscreen : icons.fullscreen,
                              widget.state.fullscreen ? labels.exitFullscreen : labels.fullscreen,
                              widget.onFullscreenToggle,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // The slider yields these keys, so one key event produces one seek.
    final bindings = <FrostShortcut, VoidCallback>{
      const FrostShortcut(LogicalKeyboardKey.space): () => _invoke(widget.onPlayPause),
      const FrostShortcut(LogicalKeyboardKey.keyK): () => _invoke(widget.onPlayPause),
      const FrostShortcut(LogicalKeyboardKey.arrowLeft): () => _seek((_preview ?? _position) - _videoSeekStep.inSeconds),
      const FrostShortcut(LogicalKeyboardKey.arrowRight): () => _seek((_preview ?? _position) + _videoSeekStep.inSeconds),
      if (widget.onMuteToggle != null) const FrostShortcut(LogicalKeyboardKey.keyM): () => _invoke(widget.onMuteToggle),
      if (widget.onFullscreenToggle != null) const FrostShortcut(LogicalKeyboardKey.keyF): () => _invoke(widget.onFullscreenToggle),
    };
    for (final binding in bindings.entries) {
      frame = frame.frostShortcut(binding.key, binding.value);
    }
    return frame;
  }
}
