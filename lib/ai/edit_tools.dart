import 'dart:convert';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../model/media_asset.dart';
import '../model/project.dart';
import '../model/title_item.dart';
import '../model/video_clip.dart';
import '../memes/meme_search.dart';
import '../model/overlay_item.dart';
import '../settings/preferences.dart';
import '../transcript/transcript.dart';
import 'meme_tools.dart';
import '../titles/templates.dart';
import 'project_summary.dart';

/// What tools need besides the project.
class ToolContext {
  const ToolContext({
    this.renderIntro,
    this.playhead = Duration.zero,
    this.preferences = const Preferences(),
    this.findMemes,
    this.memeCommands,
    this.memeChoices,
    this.transcript = const [],
  });

  /// Renders an intro clip for "before the video" titles. Null where
  /// rendering isn't possible (then those requests fail politely).
  final Future<MediaAsset> Function(
    Project project,
    TitleSpec spec, {
    String? id,
  })?
  renderIntro;
  final Duration playhead;
  final Preferences preferences;

  /// Searches your memes folder, then GIPHY. Null where memes aren't
  /// available.
  final Future<List<Meme>> Function(String query, {bool stickers})? findMemes;

  /// Downloads/reads a meme and returns the commands that place it.
  final Future<List<EditCommand>> Function(
    Project project,
    Meme meme,
    Duration start,
    OverlayTransform transform,
    Duration? duration,
    OverlayAnimation animation,
  )?
  memeCommands;

  /// Memes from earlier searches by the id shown to the user ("meme3"),
  /// kept across messages so "use meme3" works later.
  final Map<String, Meme>? memeChoices;

  /// What's said and when, on the timeline, for "when I talk about X".
  final List<TranscriptLine> transcript;
}

/// What happened when the assistant called a tool.
class ToolOutcome {
  const ToolOutcome({
    required this.project,
    required this.result,
    this.command,
    this.isError = false,
    this.seekTo,
    this.memes = const [],
    this.suggestions = const [],
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

  /// Search results to show in the chat, so the user can pick one.
  final List<(String, Meme)> memes;

  /// Memes suggested for the user to accept or reject.
  final List<MemeSuggestion> suggestions;
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

  static const _fieldsSchema = {
    'type': 'object',
    'description':
        'Template fields by key, e.g. {"title": "Weekly Rails Tips", '
        '"accent": "#00B894", "font": "Bebas Neue"}. Colours are #RRGGBB.',
    'additionalProperties': {'type': 'string'},
  };

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
      'add_title',
      'Add an intro or title. "before" puts a full-screen card before the '
          'video (only full-screen templates); "over" draws it over the '
          'video from `start`. Fields you leave out use the user\'s saved '
          'name and brand colour, then the template defaults.',
      {
        'template': {
          'type': 'string',
          'enum': [for (final t in titleTemplates) t.id],
        },
        'placement': {
          'type': 'string',
          'enum': ['before', 'over'],
        },
        'start': {
          ..._timeSchema,
          'description': 'For "over": timeline seconds where it appears.',
        },
        'duration': {'type': 'number', 'minimum': 2, 'maximum': 10},
        'fields': _fieldsSchema,
      },
      ['template', 'placement'],
    ),
    _tool(
      'edit_title',
      'Change an existing title (title_id from "titles") or intro clip '
          '(clip_id of a clip with "intro"). Only the fields you pass change.',
      {
        'title_id': {'type': 'string'},
        'clip_id': {'type': 'string'},
        'fields': _fieldsSchema,
        'duration': {'type': 'number', 'minimum': 2, 'maximum': 10},
        'start': {
          ..._timeSchema,
          'description': 'New start, for titles over the video.',
        },
      },
      [],
    ),
    _tool(
      'remove_title',
      'Remove a title that is drawn over the video. (An intro before the '
          'video is a clip: use delete_clip.)',
      {
        'title_id': {'type': 'string'},
      },
      ['title_id'],
    ),
    _tool(
      'search_memes',
      'Look for memes in the user\'s memes folder and on GIPHY. Returns up '
          'to 6 options with ids like "meme3"; the user sees them as numbered '
          'thumbnails in the chat. Not an edit.',
      {
        'query': {
          'type': 'string',
          'description': 'What the meme is, e.g. "this is fine".',
        },
        'stickers': {
          'type': 'boolean',
          'description': 'See-through stickers instead of GIFs.',
        },
      },
      ['query'],
    ),
    _tool(
      'add_meme',
      'Put a meme on the video. "meme" is an id from search_memes, or words '
          'to search for (the best match is used). Time it with "phrase" '
          '(words the user says, found in the transcript) or "start"; '
          'without either it goes at the playhead.',
      {
        'meme': {'type': 'string'},
        'phrase': {
          'type': 'string',
          'description': 'Words from the transcript where it should appear.',
        },
        'start': _timeSchema,
        'position': {'type': 'string', 'enum': memePositions},
        'size': {'type': 'string', 'enum': memeSizes.keys.toList()},
        'duration': {
          'type': 'number',
          'minimum': 0.5,
          'maximum': 15,
          'description': 'Seconds on screen; default 3 (or the clip length).',
        },
        'animation': {
          'type': 'string',
          'enum': [for (final a in OverlayAnimation.values) a.name],
        },
      },
      ['meme'],
    ),
    _tool(
      'suggest_memes',
      'Suggest a few memes for the user to accept or reject one by one in '
          'the chat, for "suggest memes for this video". Nothing is added '
          'until they accept. Pick funny, fitting moments from the '
          'transcript.',
      {
        'suggestions': {
          'type': 'array',
          'maxItems': 5,
          'items': {
            'type': 'object',
            'properties': {
              'meme': {
                'type': 'string',
                'description': 'Words to search for, or a search_memes id.',
              },
              'phrase': {'type': 'string'},
              'start': _timeSchema,
              'position': {'type': 'string', 'enum': memePositions},
              'reason': {
                'type': 'string',
                'description': 'A few words on why it fits.',
              },
            },
            'required': ['meme', 'reason'],
            'additionalProperties': false,
          },
        },
      },
      ['suggestions'],
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
  Future<ToolOutcome> run(
    String name,
    Map<String, dynamic> input,
    Project project, {
    String? invalidJson,
    ToolContext context = const ToolContext(),
  }) async {
    if (invalidJson != null) {
      return ToolOutcome(
        project: project,
        isError: true,
        result: jsonEncode({'INVALID_JSON': invalidJson}),
      );
    }
    try {
      if (name == 'search_memes') {
        return await _searchMemes(input, project, context);
      }
      if (name == 'suggest_memes') {
        return await _suggestMemes(input, project, context);
      }
      final (command, seekTo) = await _commandFor(
        name,
        input,
        project,
        context,
      );
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
    } on Exception catch (e) {
      // Rendering an intro can fail (e.g. FFmpeg missing).
      return ToolOutcome(project: project, isError: true, result: '$e');
    }
  }

  Future<(EditCommand?, Duration?)> _commandFor(
    String name,
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
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
      'add_title' => (await _addTitle(input, project, context), null),
      'edit_title' => (await _editTitle(input, project, context), null),
      'remove_title' => (RemoveTitle(_string(input, 'title_id')), null),
      'seek' => (null, _clampToProject(_time(input, 'time'), project)),
      'add_meme' => (await _addMeme(input, project, context), null),
      _ => throw _BadInput('Unknown tool "$name".'),
    };
  }

  Future<EditCommand> _addTitle(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final template = templateById(_string(input, 'template'))!;
    final placement = _string(input, 'placement');
    final fields = _fields(input, template) ?? {};
    // Fill in the user's saved name and brand colour where not given.
    final prefs = context.preferences;
    if (prefs.yourName.isNotEmpty &&
        template.fields.any((f) => f.key == 'name') &&
        !fields.containsKey('name')) {
      fields['name'] = prefs.yourName;
    }
    final brand = template.brandField;
    if (prefs.brandColor.isNotEmpty &&
        brand != null &&
        !fields.containsKey(brand)) {
      fields[brand] = prefs.brandColor;
    }
    final spec = TitleSpec(
      templateId: template.id,
      fields: fields,
      duration: input.containsKey('duration')
          ? _seconds(_number(input, 'duration', 2, 10))
          : template.defaultDuration,
    );

    if (placement == 'over') {
      return AddTitle(
        TitleItem(
          id: newId(),
          spec: spec,
          start: input.containsKey('start')
              ? _time(input, 'start')
              : Duration.zero,
        ),
      );
    }
    if (placement != 'before') {
      throw _BadInput('"placement" must be "before" or "over".');
    }
    if (!template.fullFrame) {
      throw _BadInput(
        '${template.id} is see-through, so it can only go "over" the video.',
      );
    }
    final render = context.renderIntro;
    if (render == null) throw _BadInput('Intros can\'t be rendered here.');
    final media = await render(project, spec);
    return Batch('Add intro', [
      AddMedia(media),
      AddClip(
        VideoClip(
          id: newId(),
          mediaId: media.id,
          sourceStart: Duration.zero,
          sourceEnd: media.duration,
        ),
        index: 0,
      ),
    ]);
  }

  Future<EditCommand> _editTitle(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final titleId = input['title_id'];
    final clipId = input['clip_id'];
    if ((titleId == null) == (clipId == null)) {
      throw _BadInput('Pass exactly one of "title_id" or "clip_id".');
    }

    TitleSpec merge(TitleSpec spec) {
      final template = templateById(spec.templateId)!;
      return spec.copyWith(
        fields: {...spec.fields, ...?_fields(input, template)},
        duration: input.containsKey('duration')
            ? _seconds(_number(input, 'duration', 2, 10))
            : spec.duration,
      );
    }

    if (titleId != null) {
      final title = project.titles.where((t) => t.id == titleId).firstOrNull;
      if (title == null) throw _BadInput('There is no title "$titleId".');
      return UpdateTitle(
        title.id,
        spec: merge(title.spec),
        start: input.containsKey('start') ? _time(input, 'start') : null,
      );
    }

    final clip = project.clips.where((c) => c.id == clipId).firstOrNull;
    final media = clip == null ? null : project.mediaById(clip.mediaId);
    if (media?.title == null) {
      throw _BadInput('"$clipId" is not an intro clip.');
    }
    if (input.containsKey('start')) {
      throw _BadInput(
        'An intro before the video has no start time; use move_clip.',
      );
    }
    final render = context.renderIntro;
    if (render == null) throw _BadInput('Intros can\'t be rendered here.');
    return ReplaceGeneratedMedia(
      await render(project, merge(media!.title!), id: media.id),
    );
  }

  Future<ToolOutcome> _searchMemes(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final find = context.findMemes;
    final choices = context.memeChoices;
    if (find == null || choices == null) {
      throw _BadInput('Memes aren\'t available here.');
    }
    final query = _string(input, 'query');
    final stickers = input['stickers'];
    if (stickers != null && stickers is! bool) {
      throw _BadInput('"stickers" must be true or false.');
    }
    final found = (await find(
      query,
      stickers: stickers == true,
    )).take(6).toList();
    if (found.isEmpty) {
      return ToolOutcome(
        project: project,
        result: 'No memes found for "$query". Try other words.',
      );
    }
    final shown = <(String, Meme)>[];
    for (final m in found) {
      final id = 'meme${choices.length + 1}';
      choices[id] = m;
      shown.add((id, m));
    }
    return ToolOutcome(
      project: project,
      memes: shown,
      result: jsonEncode({
        'options': [
          for (final (id, m) in shown) {...m.toJson(), 'id': id},
        ],
        'note':
            'The user sees these as thumbnails. If they asked for a specific '
            'meme and the first fits, use it; otherwise ask which one.',
      }),
    );
  }

  Future<Meme> _resolveMeme(String ref, ToolContext context) async {
    final choice = context.memeChoices?[ref.trim().toLowerCase()];
    if (choice != null) return choice;
    final find = context.findMemes;
    if (find == null) throw _BadInput('Memes aren\'t available here.');
    final found = await find(ref);
    if (found.isEmpty) {
      throw _BadInput('No meme found for "$ref". Try other words.');
    }
    return found.first;
  }

  Duration _memeStart(Map<String, dynamic> input, ToolContext context) {
    final phrase = input['phrase'];
    if (phrase != null) {
      if (phrase is! String) throw _BadInput('"phrase" must be a string.');
      if (context.transcript.isEmpty) {
        throw _BadInput(
          'The video has no transcript yet, so use "start" instead.',
        );
      }
      final line = findPhrase(context.transcript, phrase);
      if (line == null) {
        throw _BadInput(
          'Couldn\'t find "$phrase" in the transcript. Check the wording '
          'or use "start".',
        );
      }
      return line.start;
    }
    if (input.containsKey('start')) return _time(input, 'start');
    return context.playhead;
  }

  String _enum(
    Map<String, dynamic> input,
    String key,
    List<String> values,
    String fallback,
  ) {
    final v = input[key];
    if (v == null) return fallback;
    if (v is! String || !values.contains(v)) {
      throw _BadInput('"$key" must be one of: ${values.join(', ')}.');
    }
    return v;
  }

  Future<EditCommand> _addMeme(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final add = context.memeCommands;
    if (add == null) throw _BadInput('Memes aren\'t available here.');
    final meme = await _resolveMeme(_string(input, 'meme'), context);
    final start = _memeStart(input, context);
    final position = _enum(input, 'position', memePositions, 'center');
    final size = _enum(input, 'size', memeSizes.keys.toList(), 'medium');
    final animation = OverlayAnimation.values.byName(
      _enum(input, 'animation', [
        for (final a in OverlayAnimation.values) a.name,
      ], OverlayAnimation.pop.name),
    );
    final duration = input.containsKey('duration')
        ? _seconds(_number(input, 'duration', 0.5, 15))
        : null;
    if (start >= project.duration) {
      throw _BadInput(
        '${formatTime(start)} is past the end of the video '
        '(${formatTime(project.duration)}).',
      );
    }
    final room = project.duration - start;
    final commands = await add(
      project,
      meme,
      start,
      memeTransform(position, memeSizes[size]!),
      duration != null && duration > room ? room : duration,
      animation,
    );
    return Batch('Add meme "${meme.title}"', commands);
  }

  Future<ToolOutcome> _suggestMemes(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final raw = input['suggestions'];
    if (raw is! List || raw.isEmpty) {
      throw _BadInput('"suggestions" must be a list of 1 to 5 items.');
    }
    final out = <MemeSuggestion>[];
    final problems = <String>[];
    for (final item in raw.take(5)) {
      if (item is! Map<String, dynamic>) {
        throw _BadInput('Each suggestion must be an object.');
      }
      try {
        final meme = await _resolveMeme(_string(item, 'meme'), context);
        final start = _memeStart(item, context);
        if (start >= project.duration) {
          throw _BadInput('${formatTime(start)} is past the end.');
        }
        out.add(
          MemeSuggestion(
            meme: meme,
            start: start,
            position: _enum(item, 'position', memePositions, 'bottom-right'),
            size: memeSizes['medium']!,
            reason: _string(item, 'reason'),
          ),
        );
      } on _BadInput catch (e) {
        problems.add('${item['meme']}: ${e.message}');
      }
    }
    if (out.isEmpty) throw _BadInput(problems.join(' '));
    return ToolOutcome(
      project: project,
      suggestions: out,
      result: jsonEncode({
        'shown': out.length,
        if (problems.isNotEmpty) 'skipped': problems,
        'note':
            'The user accepts or rejects each one in the chat. Don\'t add '
            'them yourself. Only mention the ${out.length} shown'
            '${problems.isEmpty ? '' : '; the skipped ones had no meme'}.',
      }),
    );
  }

  /// Checks `fields` against the template: known keys, valid colours and
  /// fonts.
  Map<String, String>? _fields(
    Map<String, dynamic> input,
    TitleTemplate template,
  ) {
    final raw = input['fields'];
    if (raw == null) return null;
    if (raw is! Map<String, dynamic>) {
      throw _BadInput('"fields" must be an object.');
    }
    final out = <String, String>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      final field = template.fields.where((f) => f.key == key).firstOrNull;
      if (field == null) {
        throw _BadInput(
          '${template.id} has no field "$key". Its fields: '
          '${template.fields.map((f) => f.key).join(', ')}.',
        );
      }
      if (value is! String) throw _BadInput('Field "$key" must be a string.');
      if (field.kind == FieldKind.color && parseHexColor(value) == null) {
        throw _BadInput('Field "$key" must be a colour like #6C5CE7.');
      }
      if (field.kind == FieldKind.font && !titleFonts.contains(value)) {
        throw _BadInput(
          'Field "$key" must be one of: ${titleFonts.join(', ')}.',
        );
      }
      out[key] = field.kind == FieldKind.color ? value.toUpperCase() : value;
    }
    return out;
  }

  Duration _seconds(double s) => Duration(microseconds: (s * 1e6).round());

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
