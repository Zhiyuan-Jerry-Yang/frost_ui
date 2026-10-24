import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_window/frost_window.dart';
import '../../frost_ui/test/support.dart';

void main() {
  const channel = MethodChannel('frost_window_host_test');
  late FrostWindowController controller;
  late List<MethodCall> calls;
  var failConfigure = false;
  setUp(() {
    calls = [];
    failConfigure = false;
  });
  void mockChannel() {
    controller = FrostWindowController(minimumSize: const Size(480, 360), channel: channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'configure' && failConfigure) throw PlatformException(code: 'window_unavailable');
      return call.method == 'getState' ? <String, Object>{'revision': 1, 'active': true} : null;
    });
  }

  tearDown(() {
    controller.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('backdrop uses native actual state and live system transparency, with safe unsupported fallback', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    mockChannel();
    try {
      var active = false, solid = false, available = false;
      Widget tree({bool appSolid = false, FrostWindowBackdrop mode = FrostWindowBackdrop.mica, Brightness brightness = Brightness.light}) => FrostScope(
        config: testConfig,
        reduceTransparency: appSolid,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: FrostWindowHost(
            controller: controller,
            title: 'Backdrop',
            backdrop: mode,
            child: Builder(
              builder: (context) {
                active = FrostWindowCaptionScope.systemBackdropActiveOf(context);
                available = FrostWindowCaptionScope.systemBackdropAvailableOf(context);
                solid = FrostScope.solidSurfaces(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree());
      for (var i = 0; i < 10; i++) {
        await tester.pump();
      }
      expect(calls.where((c) => c.method == 'setBackdrop').last.arguments, {'backdrop': 'mica', 'reduceTransparency': false});
      expect(available, false);
      expect(active, false); // Unsupported is normal, never a caption failure.
      expect(controller.failed, false);
      void native(bool enabled, bool reduce, int revision) {
        tester.binding.channelBuffers.push(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('stateChanged', {'revision': revision, 'backdropActive': enabled, 'backdropAvailable': !reduce, 'reduceTransparency': reduce}),
          ),
          (_) {},
        );
      }

      native(true, false, 2);
      await tester.pumpAndSettle();
      expect(available, true);
      expect(active, true);
      expect(solid, false);
      native(false, true, 3);
      await tester.pumpAndSettle();
      expect(active, false);
      expect(solid, true);
      native(true, false, 4);
      await tester.pumpAndSettle();
      expect(active, true);
      expect(solid, false);
      await tester.pumpWidget(tree(appSolid: true, mode: FrostWindowBackdrop.micaAlt, brightness: Brightness.dark));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'setBackdrop').last.arguments, {'backdrop': 'micaAlt', 'reduceTransparency': true});
      expect(calls.where((c) => c.method == 'setToolbar').last.arguments, {'title': 'Backdrop', 'dark': true});
      expect(active, false);
      expect(solid, true);
      await tester.pumpWidget(tree(mode: FrostWindowBackdrop.none));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'setBackdrop').last.arguments, {'backdrop': 'none', 'reduceTransparency': false});
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('host converts actual layout regions and synchronizes toolbar without native plugin', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    mockChannel();
    try {
      Widget host(String title, Widget child, double? resizeBorderWidth) => resizeBorderWidth == null
          ? FrostWindowHost(controller: controller, title: title, child: child)
          : FrostWindowHost(controller: controller, title: title, resizeBorderWidth: resizeBorderWidth, child: child);
      Widget tree(String title, Brightness brightness, {double? resizeBorderWidth}) => MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: host(
          title,
          const Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 20, top: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FrostCaptionRegion(kind: FrostHitKind.caption, child: SizedBox(width: 100, height: 40)),
                  FrostCaptionRegion(kind: FrostHitKind.maximize, child: SizedBox(width: 46, height: 40)),
                ],
              ),
            ),
          ),
          resizeBorderWidth,
        ),
      );
      await tester.pumpWidget(tree('Prototype', Brightness.light));
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(controller.ready, true);
      expect(calls.where((c) => c.method == 'setResizeBorder').single.arguments, 4.0);
      expect(calls.where((c) => c.method == 'configure').single.arguments, [480.0, 360.0]);
      expect(calls.where((c) => c.method == 'setRegions').last.arguments, [
        [20.0, 12.0, 120.0, 52.0, 'caption'],
        [120.0, 12.0, 166.0, 52.0, 'maximize'],
      ]);
      expect(calls.where((c) => c.method == 'setToolbar').last.arguments, {'title': 'Prototype', 'dark': false});
      final count = calls.where((c) => c.method == 'setRegions').length;
      await tester.pump();
      expect(calls.where((c) => c.method == 'setRegions').length, count);
      await tester.pumpWidget(tree('Updated', Brightness.dark, resizeBorderWidth: 2));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'setToolbar').last.arguments, {'title': 'Updated', 'dark': true});
      expect(calls.where((c) => c.method == 'setResizeBorder').map((c) => c.arguments), [4.0, 2.0]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls.where((c) => c.method == 'setRegions').last.arguments, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('initialization failure is observable, retry resends geometry and operations are bridged', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    mockChannel();
    try {
      failConfigure = true;
      late FrostWindowActions window;
      await tester.pumpWidget(
        MaterialApp(
          home: FrostWindowHost(
            controller: controller,
            title: 'Retry',
            child: Builder(
              builder: (context) {
                window = FrostWindowCaptionScope.windowOf(context)!;
                return const Align(
                  alignment: Alignment.topLeft,
                  child: FrostCaptionRegion(kind: FrostHitKind.caption, child: SizedBox(width: 100, height: 40)),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump();
      }
      expect(window.captionState.failed, true);
      failConfigure = false;
      final retry = window.retry();
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump();
      }
      await retry;
      await tester.pumpAndSettle();
      expect(window.captionState.failed, false);
      expect(controller.ready, true);
      expect(calls.where((c) => c.method == 'setRegions').last.arguments, [
        [0.0, 0.0, 100.0, 40.0, 'caption'],
      ]);
      await window.minimize();
      await window.toggleMaximized();
      await window.close();
      expect(calls.map((c) => c.method), containsAllInOrder(['minimize', 'toggleMaximized', 'close']));
      tester.binding.channelBuffers.push(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('stateChanged', {'revision': 2, 'maximized': true, 'active': false, 'hoveredButton': 'maximize', 'pressedButton': 'maximize'}),
        ),
        (_) {},
      );
      await tester.pump();
      expect(window.captionState.maximized, true);
      expect(window.captionState.active, false);
      expect(window.captionState.maximizeHovered, true);
      expect(window.captionState.maximizePressed, true);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('native and keyboard Back reach focused content action', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    mockChannel();
    try {
      var back = 0;
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: FrostWindowHost(
            controller: controller,
            title: 'Back',
            child: Actions(
              actions: {
                FrostBackIntent: CallbackAction<FrostBackIntent>(
                  onInvoke: (_) {
                    back++;
                    return null;
                  },
                ),
              },
              child: Focus(focusNode: focus, autofocus: true, child: const SizedBox.expand()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump();
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      expect(back, 1);
      tester.binding.channelBuffers.push(channel.name, const StandardMethodCodec().encodeMethodCall(const MethodCall('navigateBack')), (_) {});
      await tester.pump();
      expect(back, 2);
      await tester.pumpWidget(const SizedBox());
      focus.dispose();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile leaves child and desktop channel untouched', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    mockChannel();
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        MaterialApp(
          home: FrostWindowHost(
            controller: controller,
            title: 'Native',
            child: const SizedBox(key: ValueKey('content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.byKey(const ValueKey('content')), findsOneWidget);
      expect(find.byType(FrostWindowCaptionScope), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('Tab reaches captions, preserves Back focus and keeps dialogs in their own loop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    mockChannel();
    late BuildContext contentContext;
    var back = 0;
    try {
      await tester.pumpWidget(
        FrostScope(
          config: testConfig,
          child: MaterialApp(
            theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
            builder: (context, child) => FrostWindowHost(
              controller: controller,
              title: 'Focus',
              child: Column(
                children: [
                  const SizedBox(
                    height: 40,
                    child: Align(alignment: Alignment.topRight, child: FrostCaptionButtons()),
                  ),
                  Expanded(child: child!),
                ],
              ),
            ),
            home: Builder(
              builder: (context) {
                contentContext = context;
                return Actions(
                  actions: {
                    FrostBackIntent: CallbackAction<FrostBackIntent>(
                      onInvoke: (_) {
                        back++;
                        return null;
                      },
                    ),
                  },
                  child: TextButton(autofocus: true, onPressed: () {}, child: const Text('Content')),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FrostCaptionButtons>(), isNotNull, reason: debugDescribeFocusTree());
      tester.binding.channelBuffers.push(channel.name, const StandardMethodCodec().encodeMethodCall(const MethodCall('navigateBack')), (_) {});
      await tester.pump();
      expect(back, 1);
      final dialog = showDialog<void>(
        context: contentContext,
        builder: (context) => AlertDialog(
          actions: [TextButton(autofocus: true, onPressed: () {}, child: const Text('Dialog'))],
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<AlertDialog>(), isNotNull);
      Navigator.of(contentContext).pop();
      await tester.pumpAndSettle();
      await dialog;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
