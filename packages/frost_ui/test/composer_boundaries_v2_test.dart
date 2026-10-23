import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:frost_ui/src/social/thread.dart' show FrostThreadRender;
import 'support.dart';

void main() {
  testWidgets('composer empty content, removal, cancellation and keyboard safe-area slot', (tester) async {
    final text = TextEditingController(), focus = FocusNode();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    var cancel = 0, remove = 0;
    Widget view({bool attached = false, double inset = 0}) => frostTestApp(
      MediaQuery(
        data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: FrostComposer(
              controller: text,
              focusNode: focus,
              placeholder: 'Write',
              onSend: (_) {},
              replyingTo: const Text('Reply'),
              onCancelReply: () => cancel++,
              attachments: [if (attached) FrostComposerAttachment(thumbnail: const SizedBox.expand(), label: 'Photo', onRemove: () => remove++)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(view());
    Finder send() => find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.send');
    expect(tester.widget<FrostButtonControl>(send()).onPressed, isNull);
    final initial = tester.getSize(find.byType(FrostComposer)).height;
    await tester.pumpWidget(view(inset: 100));
    expect(tester.getSize(find.byType(FrostComposer)).height, closeTo(initial + 100, .01));
    await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.close'));
    expect(cancel, 1);
    await tester.pumpWidget(view(attached: true));
    expect(tester.widget<FrostButtonControl>(send()).onPressed, isNotNull);
    expect(tester.getSize(find.byType(FrostMediaFrame)), const Size(56, 56));
    await tester.tap(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.remove'));
    expect(remove, 1);
  });
  testWidgets('duplicate Enter while sending calls once and uses delayed activity gate', (tester) async {
    final text = TextEditingController(text: 'Send'), focus = FocusNode(), completion = Completer<void>();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: FrostComposer(
            controller: text,
            focusNode: focus,
            placeholder: 'Write',
            onSend: (_) {
              calls++;
              return completion.future;
            },
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    expect(TickerMode.valuesOf(tester.element(find.byType(FrostActivityIndicator))).enabled, isFalse);
    await tester.pump(const Duration(milliseconds: 300));
    expect(TickerMode.valuesOf(tester.element(find.byType(FrostActivityIndicator))).enabled, isTrue);
    completion.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion composer height changes directly', (tester) async {
    final text = TextEditingController(text: 'One'), focus = FocusNode();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Align(
            alignment: Alignment.topLeft,
            child: FrostComposer(controller: text, focusNode: focus, placeholder: 'Write', onSend: (_) {}),
          ),
        ),
      ),
    );
    final initial = tester.getSize(find.byType(FrostFieldFrame)).height;
    text.text = 'One\nTwo\nThree';
    await tester.pump();
    final full = tester.getSize(find.byType(FrostFieldFrame)).height;
    expect(full, greaterThan(initial));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(find.byType(FrostFieldFrame)).height, full);
  });
  testWidgets('siblings share one stem ending at actual final avatar', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: FrostThread(
              item: const FrostThreadItem(
                avatar: FrostAvatar(semanticLabel: 'Root'),
                author: 'Root',
                body: Text('Root'),
              ),
              replies: [
                const FrostThread(
                  item: FrostThreadItem(
                    avatar: FrostAvatar(semanticLabel: 'A'),
                    author: 'A',
                    body: Text('Long\nreply\nbody'),
                  ),
                ),
                const FrostThread(
                  item: FrostThreadItem(
                    avatar: FrostAvatar(key: ValueKey('last'), semanticLabel: 'B'),
                    author: 'B',
                    body: Text('Last'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final root = tester.allRenderObjects.whereType<FrostThreadRender>().firstWhere((render) => render.replyCount == 2);
    expect(root.connections, hasLength(3));
    final end = root.connections.last.getBounds().bottom + root.localToGlobal(Offset.zero).dy;
    expect(end, tester.getCenter(find.byKey(const ValueKey('last'))).dy);
  });
}
