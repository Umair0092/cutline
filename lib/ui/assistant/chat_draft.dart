import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A prompt handed to the chat from elsewhere (a phone tool rail, the memes
/// tab): the chat picks it up, shows the assistant tab, and either fills
/// the box or sends it straight away.
class ChatDraft {
  const ChatDraft(this.text, {this.send = false, this.attachments = const []});

  final String text;
  final bool send;
  final List<String> attachments;
}

class ChatDraftController extends Notifier<ChatDraft?> {
  @override
  ChatDraft? build() => null;

  void set(ChatDraft draft) => state = draft;

  /// Called by the chat once it has used the draft.
  ChatDraft? take() {
    final d = state;
    state = null;
    return d;
  }
}

final chatDraftProvider = NotifierProvider<ChatDraftController, ChatDraft?>(
  ChatDraftController.new,
);
