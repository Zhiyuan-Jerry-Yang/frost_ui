import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:frost_ui/src/social/thread.dart' show FrostThreadRender;

import 'support.dart';

FrostThread thread(int depth, {Key? key, String? author}) => FrostThread(
  key: key,
  item: FrostThreadItem(
    avatar: SizedBox(
      key: ValueKey('avatar-$depth'),
      child: const FrostAvatar(semanticLabel: 'avatar'),
    ),
    author: author ?? 'Author $depth',
    meta: 'now',
    body: Text('Body $depth'),
  ),
  replies: depth < 5 ? [thread(depth + 1)] : [],
);
Widget frame(Widget child, {TextDirection direction = TextDirection.ltr}) => frostTestApp(
  Directionality(
    textDirection: direction,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);
FrostButtonControl send(WidgetTester tester) =>
    tester.widget<FrostButtonControl>(find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.send'));
Finder get sendFinder => find.byWidgetPredicate((w) => w is FrostButtonControl && w.label == 'L.send');
void main() {
  for (final direction in TextDirection.values) {
    testWidgets('thread real endpoints, 8 bend and depth cap $direction on first frame', (tester) async {
      await tester.pumpWidget(frame(thread(0), direction: direction));
      final parent = tester.getRect(find.byKey(const ValueKey('avatar-0')));
      final child = tester.getRect(find.byKey(const ValueKey('avatar-1')));
      expect(parent.size, const Size(32, 32));
      expect((child.center.dx - parent.center.dx).abs(), 40);
      final third = tester.getRect(find.byKey(const ValueKey('avatar-3')));
      final fourth = tester.getRect(find.byKey(const ValueKey('avatar-4')));
      expect(third.center.dx, fourth.center.dx);
      final root = tester.allRenderObjects.whereType<FrostThreadRender>().first;
      final paths = root.connections;
      expect(paths, hasLength(2));
      final branch = paths[1].getBounds();
      final rootGlobal = root.localToGlobal(Offset.zero);
      expect(branch.bottom + rootGlobal.dy, child.center.dy);
      expect(paths[0].getBounds().top + rootGlobal.dy, parent.bottom + 4);
      expect(branch.height, 8);
      if (direction == TextDirection.ltr) {
        expect(branch.right + rootGlobal.dx, child.left - 4);
      } else {
        expect(branch.left + rootGlobal.dx, child.right + 4);
      }
      final capped = tester.allRenderObjects.whereType<FrostThreadRender>().firstWhere((render) => render.indent == 0 && render.replyCount > 0);
      expect(capped.connections, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('new reply Presence expands its gap and line with real height', (tester) async {
    var replies = <FrostThread>[];
    StateSetter? update;
    await tester.pumpWidget(
      frame(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostThread(
              item: const FrostThreadItem(
                avatar: FrostAvatar(semanticLabel: 'root'),
                author: 'Root',
                body: Text('Root body'),
              ),
              replies: replies,
              collapsedReplyCount: 2,
              onShowReplies: () {},
            );
          },
        ),
      ),
    );
    expect(find.text('L.showReplies(2)'), findsOneWidget);
    final replyInk = tester
        .renderObject<RenderParagraph>(find.descendant(of: find.text('L.showReplies(2)'), matching: find.byType(RichText)))
        .text
        .style!
        .color;
    expect(replyInk, FrostThemeTokens.of(tester.element(find.byType(FrostThread).first)).accentInk);
    final original = tester.getSize(find.byType(FrostThread).first).height;
    update!(
      () => replies = [
        const FrostThread(
          key: ValueKey('new'),
          item: FrostThreadItem(
            avatar: FrostAvatar(semanticLabel: 'child'),
            author: 'New',
            body: Text('Reply'),
          ),
        ),
      ],
    );
    await tester.pump();
    expect(tester.getSize(find.byType(FrostThread).first).height, original);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getSize(find.byType(FrostThread).first).height;
    expect(middle, greaterThan(original));
    final root = tester.allRenderObjects.whereType<FrostThreadRender>().first;
    final lineEnd = root.connections.last.getBounds().bottom;
    expect(lineEnd, lessThanOrEqualTo(middle));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostThread).first).height, greaterThan(middle));
  });
  testWidgets('thread parent click does not consume action and context menu', (tester) async {
    var parent = 0, action = 0;
    await tester.pumpWidget(
      frame(
        FrostThread(
          item: FrostThreadItem(
            avatar: const FrostAvatar(semanticLabel: 'A'),
            author: 'A',
            body: const Text('Body'),
            onPressed: () => parent++,
            contextMenu: [FrostMenuAction('Menu', onSelected: () {})],
            actions: FrostButton(label: 'Action', onPressed: () => action++),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Action'));
    await tester.pump();
    expect(action, 1);
    expect(parent, 0);
    await tester.tap(find.text('Body'));
    await tester.pump();
    expect(parent, 1);
  });

  testWidgets('composer regular field, six-line cap and standard spring height', (tester) async {
    final controller = TextEditingController(text: 'one'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(frame(FrostComposer(controller: controller, focusNode: focus, placeholder: 'Write', onSend: (_) {})));
    final field = find.byType(FrostFieldFrame);
    final initial = tester.getSize(field).height;
    controller.text = 'one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\nnine';
    await tester.pump();
    expect(tester.getSize(field).height, initial);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getSize(field).height;
    expect(middle, greaterThan(initial));
    await tester.pumpAndSettle();
    final full = tester.getSize(field).height;
    expect(full, greaterThan(middle));
    final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
    expect(editable.maxLines, 6);
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(editable.maxScrollExtent, greaterThan(0));
    final decoration =
        tester.widgetList<AnimatedContainer>(find.descendant(of: field, matching: find.byType(AnimatedContainer))).first.decoration! as ShapeDecoration;
    final context = tester.element(field);
    expect(decoration.color, FrostThemeTokens.of(context).fillSubtle);
    expect((decoration.shape as RoundedSuperellipseBorder).borderRadius, FrostRadius.borderRadius(FrostRadius.md));
    expect(tester.takeException(), isNull);
  });
  testWidgets('grapheme threshold and over-limit disable without truncating', (tester) async {
    final controller = TextEditingController(text: 'a' * 7), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(frame(FrostComposer(controller: controller, focusNode: focus, placeholder: 'Write', maxLength: 10, onSend: (_) {})));
    expect(find.text('7 / 10'), findsNothing);
    controller.text = '👨‍👩‍👧‍👦' * 8;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('8 / 10'), findsOneWidget);
    expect(send(tester).onPressed, isNotNull);
    controller.text = '👨‍👩‍👧‍👦' * 11;
    await tester.pump();
    expect(send(tester).onPressed, isNull);
    expect(controller.text.characters.length, 11);
    expect(tester.widget<FrostText>(find.byWidgetPredicate((w) => w is FrostText && w.data == '11 / 10')).tone, FrostTextTone.negative);
  });
  testWidgets('future send keeps text/tools editable, locks message attachments and cancellation', (tester) async {
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final completion = Completer<void>();
    var tool = 0, remove = 0, cancel = 0, calls = 0;
    String? snapshot;
    await tester.pumpWidget(
      frame(
        FrostComposer(
          controller: controller,
          focusNode: focus,
          placeholder: 'Write',
          onSend: (text) {
            calls++;
            snapshot = text;
            return completion.future;
          },
          attachments: [
            FrostComposerAttachment(
              thumbnail: const ColoredBox(color: Colors.blue),
              label: 'Photo',
              onRemove: () => remove++,
            ),
          ],
          tools: [FrostButton.icon(icon: testIcons.attach, label: 'Tool', onPressed: () => tool++)],
          replyingTo: const Text('Replying'),
          onCancelReply: () => cancel++,
        ),
      ),
    );
    expect(send(tester).onPressed, isNotNull);
    await tester.tap(sendFinder);
    await tester.pump();
    expect(snapshot, '');
    expect(calls, 1);
    expect(send(tester).loading, isTrue);
    controller.text = 'new text';
    await tester.pump();
    await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Tool'));
    await tester.pump();
    expect(tool, 1);
    final locked = tester.widgetList<FrostButton>(find.byType(FrostButton)).where((w) => w.label == 'L.remove' || w.label == 'L.close');
    expect(locked.every((button) => button.onPressed == null), isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    completion.complete();
    await tester.pump();
    await tester.pump();
    expect(send(tester).loading, isFalse);
    expect(controller.text, 'new text');
    expect(remove, 0);
    expect(cancel, 0);
  });
  testWidgets('desktop Enter sends once; Shift+Enter and composing do not send', (tester) async {
    final controller = TextEditingController(text: 'hello'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var calls = 0;
    await tester.pumpWidget(frame(FrostComposer(controller: controller, focusNode: focus, placeholder: 'Write', onSend: (_) => calls++)));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(calls, 1);
    controller.value = const TextEditingValue(text: 'hello', composing: TextRange(start: 0, end: 5));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
  });
  testWidgets('touch Enter remains newline, external sending locks send', (tester) async {
    final controller = TextEditingController(text: 'hello'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(platform: TargetPlatform.android),
            child: FrostComposer(controller: controller, focusNode: focus, placeholder: 'Write', onSend: (_) => calls++, sending: true),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 0);
    expect(send(tester).loading, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).textInputAction, TextInputAction.newline);
  });
  testWidgets('send exception restores state; unmount discards asynchronous result', (tester) async {
    final controller = TextEditingController(text: 'hello'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(frame(FrostComposer(controller: controller, focusNode: focus, placeholder: 'Write', onSend: (_) => throw StateError('failure'))));
    await tester.tap(sendFinder);
    await tester.pump();
    expect(tester.takeException(), isStateError);
    expect(send(tester).loading, isFalse);
    expect(controller.text, 'hello');
    final done = Completer<void>();
    await tester.pumpWidget(frame(FrostComposer(controller: controller, focusNode: focus, placeholder: 'Write', onSend: (_) => done.future)));
    await tester.tap(sendFinder);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    done.completeError(StateError('late'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
