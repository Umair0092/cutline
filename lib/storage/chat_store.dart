import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../ai/chat_controller.dart';

/// The assistant conversation lives next to the project as `chat.json`.
/// It isn't part of the project model, so chatting doesn't add undo steps
/// or mark the project as edited.
class ChatStore {
  const ChatStore();

  static const file = 'chat.json';

  Future<void> save(String projectPath, ChatState chat) async {
    final tmp = File(p.join(projectPath, '$file.tmp'));
    await tmp.writeAsString(jsonEncode(chat.toJson()), flush: true);
    await tmp.rename(p.join(projectPath, file));
  }

  /// An empty chat if there's none or it can't be read; losing chat history
  /// should never stop a project from opening.
  Future<ChatState> load(String projectPath) async {
    final f = File(p.join(projectPath, file));
    if (!f.existsSync()) return const ChatState();
    try {
      return ChatState.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>,
      );
    } on Object {
      return const ChatState();
    }
  }
}
