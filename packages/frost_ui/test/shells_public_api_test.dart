import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('8B shells compile from widgets and frost_ui only', () {
    const state = FrostVideoState(
      playing: false,
      position: Duration(seconds: 1),
      duration: Duration(seconds: 60),
      buffered: Duration(seconds: 20),
      muted: true,
      fullscreen: true,
      buffering: false,
    );
    final widgets = <Widget>[
      FrostVideoFrame(video: const SizedBox(), state: state, onPlayPause: () {}, onSeek: (_) {}, onMuteToggle: () {}, onFullscreenToggle: () {}),
      FrostWebChrome(
        web: const SizedBox(),
        title: 'Title',
        url: Uri.parse('https://example.test/path'),
        loading: true,
        progress: .5,
        canGoBack: true,
        canGoForward: true,
        onBack: () {},
        onForward: () {},
        onReload: () {},
        onStop: () {},
        onOpenInBrowser: () {},
      ),
    ];
    expect(widgets, hasLength(2));
  });
}
