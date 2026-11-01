import 'dart:convert';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../model/project.dart';
import 'project_summary.dart';

/// What happened when the assistant called a tool.
class ToolOutcome {
  const ToolOutcome({
    required this.project,
    required this.result,
    this.command,
    this.isError = false,
    this.seekTo,
  });

  /// The working project after the call (unchanged on error).
  final Project project;

  /// Sent back to Claude as the tool_result content.
  final String result;

  /// The edit to commit at the end of the turn, if any.
  final EditCommand? command;
  final bool isError;

  /// Move the playhead here (not an edit).
  final Duration? seekTo;
}

class _BadInput implements Exception {
  _BadInput(this.message);
  final String message;
}

/// The editing tools the assistant can call. Each maps to the same
/// [EditCommand]s the timeline uses, so AI edits are ordinary, undoable
/// edits.
class EditToolbox {
  const EditToolbox();

  static const _timeSchema = {
    'type': 'number',
    'description': 'Timeline time in seconds, e.g. 75.5 for 1:15.5.',
  };

  Map<String, dynamic> _tool(
    String name,
    String description,
    Map<String, dynamic> properties,
    List<String> required,
  ) => {
    'name': name,
    'description': description,
    // Stream tool input as it's generated; we validate it ourselves.
    'eager_input_streaming': true,
    'input_schema': {
      'type': 'object',
      'properties': properties,
      'required': required,
      'additionalProperties': false,
    },
  };

  List<Map<String, dynamic>> get definitions => [
    _tool(
      'cut_range',
      'Remove the part of the video between two timeline times. Everything '
          'after closes the gap. Use for "cut 1:20 to 1:35", "remove the first '
          '5 seconds".',
      {'start': _timeSchema, 'end': _timeSchema},
      ['start', 'end'],
    ),
    _tool(
      'keep_only',
      'Keep only the part between two timeline times and remove the rest. '
          'Use for "trim it to 0:10–0:40".',
      {'start': _timeSchema, 'end': _timeSchema},
      ['start', 'end'],
    ),
    _tool(
      'split_at',
      'Split the clip under a timeline time into two clips.',
      {'time': _timeSchema},
      ['time'],
    ),
    _tool(
      'delete_clip',
      'Delete a whole clip by id. The gap closes.',
      {
        'clip_id': {'type': 'string'},
      },
      ['clip_id'],
    ),
    _tool(
      'move_clip',
      'Move a clip to a new position in the clip order (0 = first).',
      {
        'clip_id': {'type': 'string'},
        'to_index': {'type': 'integer', 'minimum': 0},
      },
      ['clip_id', 'to_index'],
    ),
    _tool(
      'set_clip_volume',
      'Set a clip\'s sound volume: 0 mutes it, 1 is normal, 2 is double.',
      {
        'clip_id': {'type': 'string'},
        'volume': {'type': 'number', 'minimum': 0, 'maximum': 2},
      },
      ['clip_id', 'volume'],
    ),
    _tool(
      'rename_project',
      'Rename the project.',
      {
        'name': {'type': 'string'},
      },
      ['name'],
    ),
    _tool(
      'seek',
      'Move the playhead to a time so the user can look at that moment. '
          'Not an edit.',
      {'time': _timeSchema},
      ['time'],
    ),
  ];

  /// Runs one tool call against the working project.
  ToolOutcome run(
    String name,
    Map<String, dynamic> input,
    Project project, {
    String? invalidJson,
  }) {
    if (invalidJson != null) {
      return ToolOutcome(
        project: project,
        isError: true,
        result: jsonEncode({'INVALID_JSON': invalidJson}),
      );
    }
    try {
      final (command, seekTo) = _commandFor(name, input, project);
      if (command == null) {
        return ToolOutcome(
          project: project,
          result: 'Playhead moved.',
          seekTo: seekTo,
        );
      }
      final updated = command.apply(project);
      return ToolOutcome(
        project: updated,
        command: command,
        result: jsonEncode({
          'ok': command.label,
          'project': projectSummary(updated),
        }),
      );
    } on _BadInput catch (e) {
      return ToolOutcome(project: project, isError: true, result: e.message);
    } on EditException catch (e) {
      return ToolOutcome(project: project, isError: true, result: e.message);
    }
  }

  (EditCommand?, Duration?) _commandFor(
    String name,
    Map<String, dynamic> input,
    Project project,
  ) {
    final allowed = {
      for (final d in definitions)
        d['name'] as String: ((d['input_schema'] as Map)['properties'] as Map)
            .keys
            .cast<String>()
            .toSet(),
    };
    final known = allowed[name];
    if (known == null) throw _BadInput('Unknown tool "$name".');
    final extra = input.keys.where((k) => !known.contains(k)).toList();
    if (extra.isNotEmpty) {
      throw _BadInput('Unexpected field(s): ${extra.join(', ')}.');
    }

    return switch (name) {
      'cut_range' => (
        RemoveRange(_time(input, 'start'), _time(input, 'end')),
        null,
      ),
      'keep_only' => (
        _KeepOnly(_time(input, 'start'), _time(input, 'end')),
        null,
      ),
      'split_at' => (SplitAt(_time(input, 'time')), null),
      'delete_clip' => (RemoveClip(_string(input, 'clip_id')), null),
      'move_clip' => (
        MoveClip(_string(input, 'clip_id'), _int(input, 'to_index')),
        null,
      ),
      'set_clip_volume' => (
        SetClipVolume(
          _string(input, 'clip_id'),
          _number(input, 'volume', 0, 2),
        ),
        null,
      ),
      'rename_project' => (RenameProject(_string(input, 'name')), null),
      'seek' => (null, _clampToProject(_time(input, 'time'), project)),
      _ => throw _BadInput('Unknown tool "$name".'),
    };
  }

  Duration _clampToProject(Duration t, Project p) =>
      t > p.duration ? p.duration : t;

  Duration _time(Map<String, dynamic> input, String key) {
    final seconds = _number(input, key, 0, 24 * 3600);
    return Duration(microseconds: (seconds * 1e6).round());
  }

  double _number(Map<String, dynamic> input, String key, num min, num max) {
    final v = input[key];
    if (v is! num) throw _BadInput('"$key" must be a number.');
    if (v < min || v > max) {
      throw _BadInput('"$key" must be between $min and $max.');
    }
    return v.toDouble();
  }

  int _int(Map<String, dynamic> input, String key) {
    final v = input[key];
    if (v is! int || v < 0) {
      throw _BadInput('"$key" must be a whole number, 0 or more.');
    }
    return v;
  }

  String _string(Map<String, dynamic> input, String key) {
    final v = input[key];
    if (v is! String || v.trim().isEmpty) {
      throw _BadInput('"$key" must be a non-empty string.');
    }
    return v;
  }
}

/// Keep only [start]..[end]: cut after it, then before it.
class _KeepOnly extends EditCommand {
  const _KeepOnly(this.start, this.end);
  final Duration start;
  final Duration end;

  @override
  String get label => 'Keep ${formatTime(start)}–${formatTime(end)}';

  @override
  Project apply(Project project) {
    if (end <= start) throw EditException('The end must be after the start.');
    var p = project;
    if (end < p.duration) p = RemoveRange(end, p.duration).apply(p);
    if (start > Duration.zero) p = RemoveRange(Duration.zero, start).apply(p);
    if (identical(p, project)) {
      throw EditException('That range is already the whole video.');
    }
    return p;
  }
}
