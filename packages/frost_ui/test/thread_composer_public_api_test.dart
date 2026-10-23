import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('thread and composer public API need only widgets and frost_ui', () {
    const item = FrostThreadItem(
      avatar: SizedBox(),
      author: 'Author',
      meta: 'Meta',
      body: FrostRichText(text: 'Body'),
      actions: SizedBox(),
    );
    final thread = FrostThread(item: item, replies: const [], collapsedReplyCount: 2, onShowReplies: () {});
    final attachment = FrostComposerAttachment(thumbnail: const SizedBox(), label: 'File', onRemove: () {});
    final controller = TextEditingController(), focus = FocusNode();
    final composer = FrostComposer(
      controller: controller,
      focusNode: focus,
      placeholder: 'Write',
      onSend: (_) async {},
      maxLength: 500,
      attachments: [attachment],
      tools: const [],
      replyingTo: const Text('Replying'),
      onCancelReply: () {},
      sending: false,
    );
    expect(thread.item, item);
    expect(composer.attachments.single, attachment);
    controller.dispose();
    focus.dispose();
  });
}
