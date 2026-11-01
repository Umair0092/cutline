import '../model/project.dart';

/// Thrown when an edit can't be applied, e.g. a clip id that doesn't exist or
/// a time past the end of the video. The message is shown to the user (and
/// later sent back to the AI so it can correct itself).
class EditException implements Exception {
  EditException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One change to a [Project]. Commands never mutate; they return a new
/// project or throw [EditException].
abstract class EditCommand {
  const EditCommand();

  /// Short description for the Undo menu and the AI change log,
  /// e.g. "Split clip".
  String get label;

  Project apply(Project project);
}
