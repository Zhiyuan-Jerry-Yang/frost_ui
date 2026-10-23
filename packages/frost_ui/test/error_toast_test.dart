import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_copy_feedback.dart';

import 'support.dart';

const diagnostic = 'stage=webview-create\nHRESULT=0x80070005';
Widget app(Widget child, {TargetPlatform platform = TargetPlatform.windows, String? details = diagnostic, bool rtlLarge = false}) {
  final config = testConfig.copyWith(
    errors: FrostErrorPresenter(message: (_, _) => 'Unable to open verification', details: (_) => details),
  );
  return FrostScope(
    config: config,
    child: MaterialApp(
      theme: FrostTheme.build(config: config, brightness: Brightness.light, platform: platform, locale: const Locale('en')),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(rtlLarge ? 2 : 1)),
        child: Directionality(
          textDirection: rtlLarge ? TextDirection.rtl : TextDirection.ltr,
          child: FrostToastHost(child: child!),
        ),
      ),
      home: Scaffold(body: child),
    ),
  );
}

Finder detailButton() => find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.errorDetails');
void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('structured error details open once and copy exactly $platform', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FrostButton(label: 'Fail', onPressed: () => FrostToast.fromError(context, StateError('fixture'))),
          ),
          platform: platform,
        ),
      );
      await tester.tap(find.text('Fail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Unable to open verification'), findsOneWidget);
      expect(find.text(diagnostic), findsNothing);
      expect(detailButton(), findsOneWidget);
      final action = tester.widget<FrostButton>(detailButton()).onPressed!;
      action();
      action();
      await tester.pumpAndSettle();
      expect(find.byType(FrostDialog), findsOneWidget);
      expect(tester.widget<FrostErrorDetails>(find.byType(FrostErrorDetails)).details, diagnostic);
      expect(tester.widget<FrostErrorDetails>(find.byType(FrostErrorDetails)).initiallyExpanded, isTrue);
      final copy = find.byType(FrostCopyFeedbackButton);
      expect(copy, findsOneWidget);
      await tester.tap(copy);
      await tester.pump();
      expect(copied, diagnostic);
      await tester.pumpWidget(const SizedBox());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      expect(tester.takeException(), isNull);
    });
    testWidgets('retry and details remain separate one-shot actions $platform', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FrostButton(
              label: 'Fail',
              onPressed: () => FrostToast.fromError(context, StateError('fixture'), description: '#42', actionLabel: 'Retry', onAction: () => retried++),
            ),
          ),
          platform: platform,
        ),
      );
      await tester.tap(find.text('Fail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('#42'), findsOneWidget);
      expect(detailButton(), findsOneWidget);
      final retry = tester.widget<FrostButton>(find.widgetWithText(FrostButton, 'Retry')).onPressed!;
      retry();
      retry();
      await tester.pumpAndSettle();
      expect(retried, 1);
      expect(find.byType(FrostDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('details survive the originating widget unmounting', (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, shown, _) => shown
              ? Builder(
                  builder: (context) => FrostButton(
                    label: 'Fail',
                    onPressed: () {
                      FrostToast.fromError(context, StateError('fixture'));
                      visible.value = false;
                    },
                  ),
                )
              : const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.text('Fail'));
    await tester.pumpAndSettle();
    expect(find.text('Fail'), findsNothing);
    await tester.tap(detailButton());
    await tester.pumpAndSettle();
    expect(tester.widget<FrostErrorDetails>(find.byType(FrostErrorDetails)).details, diagnostic);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow touch RTL and large text keep the detail action reachable', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FrostButton(label: 'Fail', onPressed: () => FrostToast.fromError(context, StateError('fixture'))),
        ),
        platform: TargetPlatform.android,
        rtlLarge: true,
      ),
    );
    await tester.tap(find.text('Fail'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'toast layout');
    expect(tester.getRect(detailButton()).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(detailButton()).right, lessThanOrEqualTo(360));
    expect(detailButton(), findsOneWidget);
    await tester.tap(detailButton());
    await tester.pumpAndSettle();
    expect(find.byType(FrostDialog), findsOneWidget);
    expect(tester.widget<FrostErrorDetails>(find.byType(FrostErrorDetails)).details, diagnostic);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  for (final details in <String?>[null, ' \n ']) {
    testWidgets('missing or blank details keep a plain error notice $details', (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FrostButton(label: 'Fail', onPressed: () => FrostToast.fromError(context, StateError('fixture'))),
          ),
          details: details,
        ),
      );
      await tester.tap(find.text('Fail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(detailButton(), findsNothing);
      expect(find.text('Unable to open verification'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
