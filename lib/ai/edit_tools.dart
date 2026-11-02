import 'dart:convert';

import '../editing/commands.dart';
import '../editing/edit_command.dart';
import '../model/media_asset.dart';
import '../model/project.dart';
import '../model/title_item.dart';
import '../model/video_clip.dart';
import '../memes/meme_search.dart';
import '../model/audio_item.dart';
import '../music/music_library.dart';
import '../model/overlay_item.dart';
import '../settings/preferences.dart';
import '../transcript/transcript.dart';
import '../model/speech_spec.dart';
import '../model/voice_effect.dart';
import '../voice/tts.dart';
import '../voice/voiceover_actions.dart';
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
    this.voiceover,
    this.remakeLine,
    this.findTracks,
    this.trackChoices,
    this.trackMedia,
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

  /// Speaks script lines and returns the commands that place them.
  final Future<List<EditCommand>> Function(
    Project project,
    List<ScriptLine> lines,
    VoiceEngine engine,
    String voice,
    double speed,
    Duration from,
  )?
  voiceover;

  /// Re-makes one voiceover line (an audio item made by text-to-speech).
  final Future<EditCommand> Function(
    Project project,
    String audioId,
    SpeechSpec spec,
  )?
  remakeLine;

  /// Searches the free music and sound library. Null where it isn't
  /// available.
  final Future<List<Track>> Function(String query, {TrackKind kind})?
  findTracks;

  /// Tracks from earlier searches ("music2", "sound1") and audio files the
  /// user attached ("file1"), kept across messages.
  final Map<String, Track>? trackChoices;

  /// Downloads or copies a track into the project and returns its media.
  final Future<MediaAsset> Function(Project project, Track track)? trackMedia;
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
    this.tracks = const [],
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

  /// Music or sounds found, to show (and play) in the chat.
  final List<(String, Track)> tracks;
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
        '"accent": "#00B894", "font": "Bebas Neue"}. Colours are #RRGGBB. '
        'Picture fields (logo, photo) take an image id from "images", like '
        '"img1".',
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
      'Add an intro, title or picture clip. "before" puts a full-screen '
          'card before the video, "after" at the end (only full-screen '
          'templates); "over" draws it over the video from `start`. Fields '
          'you leave out use the user\'s saved name and brand colour, then '
          'the template defaults. To make a video from pictures, add one '
          'photo-showcase per picture with "after", in order.',
      {
        'template': {
          'type': 'string',
          'enum': [for (final t in titleTemplates) t.id],
        },
        'placement': {
          'type': 'string',
          'enum': ['before', 'after', 'over'],
        },
        'start': {
          ..._timeSchema,
          'description': 'For "over": timeline seconds where it appears.',
        },
        'duration': {'type': 'number', 'minimum': 2, 'maximum': 15},
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
        'duration': {'type': 'number', 'minimum': 2, 'maximum': 15},
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
      'add_voiceover',
      'Write a voiceover and have it spoken onto the voiceover track. Each '
          'line becomes its own clip (keep lines to a sentence or two). Time '
          'a line with "phrase" (words said in the transcript, e.g. the part '
          'it explains) or "start"; lines without either follow the previous '
          'one. The video\'s own sound is lowered under it on export.',
      {
        'lines': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 20,
          'items': {
            'type': 'object',
            'properties': {
              'text': {'type': 'string'},
              'phrase': {'type': 'string'},
              'start': _timeSchema,
            },
            'required': ['text'],
            'additionalProperties': false,
          },
        },
        'engine': {
          'type': 'string',
          'enum': [for (final e in VoiceEngine.values) e.name],
          'description':
              'system: the computer\'s voices (default). groq: more '
              'natural voices.',
        },
        'voice': {
          'type': 'string',
          'description':
              'For groq: ${groqVoices.join(', ')}. Leave out for the default.',
        },
        'speed': {'type': 'number', 'minimum': 0.75, 'maximum': 1.5},
      },
      ['lines'],
    ),
    _tool(
      'remake_voiceover_line',
      'Change one voiceover line (audio_id from "audio" with "text") and '
          'speak it again: new words, voice or speed. Only what you pass '
          'changes; the other lines stay.',
      {
        'audio_id': {'type': 'string'},
        'text': {'type': 'string'},
        'voice': {'type': 'string'},
        'speed': {'type': 'number', 'minimum': 0.75, 'maximum': 1.5},
      },
      ['audio_id'],
    ),
    _tool(
      'set_voice_effect',
      'Change how a voice sounds: pitch, speed, robot, noise cleanup, '
          'even loudness. "target" is "video" (the main video\'s sound, every '
          'clip: usually the user\'s own voice), a clip_id, or an audio_id '
          'from "audio". Fields you leave out keep their current value; a '
          'preset replaces pitch and robot. "reset": true removes the effect.',
      {
        'target': {'type': 'string'},
        'preset': {
          'type': 'string',
          'enum': [for (final p in VoicePreset.values) p.name],
        },
        'pitch': {
          'type': 'number',
          'minimum': -12,
          'maximum': 12,
          'description':
              'Semitones. "A bit deeper" is about -2; "much higher" +5.',
        },
        'speed': {
          'type': 'number',
          'minimum': 0.5,
          'maximum': 2,
          'description': 'Audio track only.',
        },
        'robot': {'type': 'boolean'},
        'denoise': {'type': 'boolean'},
        'normalize': {'type': 'boolean'},
        'reset': {'type': 'boolean'},
      },
      ['target'],
    ),
    _tool(
      'search_music',
      'Look for background music or sound effects in a free library of '
          'Creative Commons tracks. Returns up to 6 options with ids like '
          '"music2" or "sound1"; the user sees them as cards they can play. '
          'Search by mood, genre or instrument ("calm lofi piano", "upbeat '
          'electronic", "epic cinematic"), not song names: famous songs '
          'aren\'t free to use. Not an edit.',
      {
        'query': {'type': 'string'},
        'kind': {
          'type': 'string',
          'enum': ['music', 'sound'],
          'description': 'music (default) or sound effects.',
        },
      },
      ['query'],
    ),
    _tool(
      'add_music',
      'Put background music under the video. "music" is an id from '
          'search_music, a "file" id of an audio file the user attached, or '
          'words to search for (the best match is used). Plays from "start" '
          'to "end" (default: the whole video), repeating if the track is '
          'shorter, with a fade in and out. Music already in that range is '
          'replaced. It\'s evened out and lowered automatically when anyone '
          'talks.',
      {
        'music': {'type': 'string'},
        'start': _timeSchema,
        'end': _timeSchema,
        'track_from': {
          'type': 'number',
          'minimum': 0,
          'description':
              'Seconds into the track to start from, e.g. to skip a slow '
              'intro.',
        },
        'level': {
          'type': 'number',
          'minimum': 0,
          'maximum': 2,
          'description':
              'Music track level (sets the mix): 0.6 is a quiet bed under '
              'talking (default), 1 is present, 1.3+ for parts without '
              'speech.',
        },
      },
      ['music'],
    ),
    _tool(
      'add_sound',
      'Add a sound effect (whoosh, applause, ding, laugh...). "sound" is an '
          'id from search_music with kind "sound", a "file" id, or words to '
          'search for. Time it with "phrase" or "start"; default the '
          'playhead.',
      {
        'sound': {'type': 'string'},
        'phrase': {'type': 'string'},
        'start': _timeSchema,
        'volume': {'type': 'number', 'minimum': 0, 'maximum': 2},
      },
      ['sound'],
    ),
    _tool(
      'set_audio_mix',
      'Set how loud each track is and what gets lowered under speech. '
          'Levels are 0 (silent) to 2 (double); 1 is normal. Only what you '
          'pass changes. "video" is the video\'s own sound (usually the '
          'user\'s voice), "voiceover" the recorded or AI voice, "music" '
          'the background music. duck_video lowers the video under '
          'voiceovers; duck_music lowers music when anyone talks.',
      {
        'video': {'type': 'number', 'minimum': 0, 'maximum': 2},
        'voiceover': {'type': 'number', 'minimum': 0, 'maximum': 2},
        'music': {'type': 'number', 'minimum': 0, 'maximum': 2},
        'duck_video': {'type': 'boolean'},
        'duck_music': {'type': 'boolean'},
      },
      [],
    ),
    _tool(
      'remove_audio',
      'Delete an audio item by audio_id (from "audio"), or every item of a '
          'role: "music", "voiceover" or "effect".',
      {
        'audio_id': {'type': 'string'},
        'role': {
          'type': 'string',
          'enum': [for (final r in AudioRole.values) r.name],
        },
      },
      [],
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
      if (name == 'search_music') {
        return await _searchMusic(input, project, context);
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
    } on MusicException catch (e) {
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
      'add_voiceover' => (await _addVoiceover(input, project, context), null),
      'set_voice_effect' => (_setVoiceEffect(input, project), null),
      'remake_voiceover_line' => (
        await _remakeLine(input, project, context),
        null,
      ),
      'add_music' => (await _addMusic(input, project, context), null),
      'add_sound' => (await _addSound(input, project, context), null),
      'set_audio_mix' => (_setMix(input, project), null),
      'remove_audio' => (_removeAudio(input, project), null),
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
    final fields = _fields(input, template, project) ?? {};
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
          ? _seconds(_number(input, 'duration', 2, 15))
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
    if (placement != 'before' && placement != 'after') {
      throw _BadInput('"placement" must be "before", "after" or "over".');
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
        index: placement == 'before' ? 0 : null,
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
        fields: {...spec.fields, ...?_fields(input, template, project)},
        duration: input.containsKey('duration')
            ? _seconds(_number(input, 'duration', 2, 15))
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

  Future<ToolOutcome> _searchMusic(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final find = context.findTracks;
    final choices = context.trackChoices;
    if (find == null || choices == null) {
      throw _BadInput('Music isn\'t available here.');
    }
    final query = _string(input, 'query');
    final kind = _enum(input, 'kind', ['music', 'sound'], 'music') == 'sound'
        ? TrackKind.sound
        : TrackKind.music;
    final found = (await find(query, kind: kind)).take(6).toList();
    if (found.isEmpty) {
      return ToolOutcome(
        project: project,
        result:
            'Nothing found for "$query". Try other words (a mood or '
            'genre).',
      );
    }
    final prefix = kind == TrackKind.music ? 'music' : 'sound';
    final shown = <(String, Track)>[];
    for (final t in found) {
      final n = choices.keys.where((k) => k.startsWith(prefix)).length + 1;
      final id = '$prefix$n';
      choices[id] = t;
      shown.add((id, t));
    }
    return ToolOutcome(
      project: project,
      tracks: shown,
      result: jsonEncode({
        'options': [
          for (final (id, t) in shown) {...t.toJson(), 'id': id},
        ],
        'note':
            'The user sees these as cards they can play. If one clearly '
            'fits, use it; otherwise ask which one they like.',
      }),
    );
  }

  Future<Track> _resolveTrack(
    String ref,
    TrackKind kind,
    ToolContext context,
  ) async {
    final choice = context.trackChoices?[ref.trim().toLowerCase()];
    if (choice != null) return choice;
    final find = context.findTracks;
    if (find == null) throw _BadInput('Music isn\'t available here.');
    final found = await find(ref, kind: kind);
    if (found.isEmpty) {
      throw _BadInput('Nothing found for "$ref". Try a mood or genre.');
    }
    return found.first;
  }

  Future<EditCommand> _addMusic(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final place = context.trackMedia;
    if (place == null) throw _BadInput('Music isn\'t available here.');
    if (project.clips.isEmpty) throw _BadInput('There is no video yet.');
    final from = input.containsKey('start')
        ? _time(input, 'start')
        : Duration.zero;
    final to = input.containsKey('end')
        ? _time(input, 'end')
        : project.duration;
    if (from >= project.duration) {
      throw _BadInput(
        '${formatTime(from)} is past the end of the video '
        '(${formatTime(project.duration)}).',
      );
    }
    if (to <= from) throw _BadInput('"end" must be after "start".');
    final track = await _resolveTrack(
      _string(input, 'music'),
      TrackKind.music,
      context,
    );
    final media = await place(project, track);
    final trackFrom = input.containsKey('track_from')
        ? _seconds(_number(input, 'track_from', 0, 24 * 3600))
        : Duration.zero;
    // Replace music that would play at the same time.
    final replaced = [
      for (final a in project.audio)
        if (a.role == AudioRole.music && a.start < to && a.end > from)
          RemoveAudio(a.id),
    ];
    final commands = <EditCommand>[
      ...replaced,
      ...musicCommands(
        project,
        media,
        from: from,
        to: to,
        sourceStart: trackFrom,
      ),
    ];
    if (input.containsKey('level')) {
      commands.add(
        SetAudioMix(project.mix.copyWith(music: _number(input, 'level', 0, 2))),
      );
    }
    return Batch('Add music "${track.title}"', commands);
  }

  Future<EditCommand> _addSound(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final place = context.trackMedia;
    if (place == null) throw _BadInput('Sounds aren\'t available here.');
    final start = _memeStart(input, context);
    if (start >= project.duration) {
      throw _BadInput(
        '${formatTime(start)} is past the end of the video '
        '(${formatTime(project.duration)}).',
      );
    }
    final track = await _resolveTrack(
      _string(input, 'sound'),
      TrackKind.sound,
      context,
    );
    final media = await place(project, track);
    return Batch(
      'Add sound "${track.title}"',
      soundCommands(
        project,
        media,
        start,
        volume: input.containsKey('volume')
            ? _number(input, 'volume', 0, 2)
            : 1,
      ),
    );
  }

  EditCommand _setMix(Map<String, dynamic> input, Project project) {
    bool? flag(String key) {
      final v = input[key];
      if (v == null) return null;
      if (v is! bool) throw _BadInput('"$key" must be true or false.');
      return v;
    }

    double? level(String key) =>
        input.containsKey(key) ? _number(input, key, 0, 2) : null;
    if (input.isEmpty) throw _BadInput('Pass at least one level or switch.');
    final m = project.mix;
    return SetAudioMix(
      m.copyWith(
        original: level('video') ?? m.original,
        voiceover: level('voiceover') ?? m.voiceover,
        music: level('music') ?? m.music,
        duck: flag('duck_video') ?? m.duck,
        duckMusic: flag('duck_music') ?? m.duckMusic,
      ),
    );
  }

  EditCommand _removeAudio(Map<String, dynamic> input, Project project) {
    final id = input['audio_id'];
    final role = input['role'];
    if ((id == null) == (role == null)) {
      throw _BadInput('Pass exactly one of "audio_id" or "role".');
    }
    if (id != null) {
      if (id is! String || !project.audio.any((a) => a.id == id)) {
        throw _BadInput('There is no audio item "$id".');
      }
      return RemoveAudio(id);
    }
    final r = AudioRole.values.byName(
      _enum(input, 'role', [for (final r in AudioRole.values) r.name], 'music'),
    );
    final items = project.audio.where((a) => a.role == r).toList();
    if (items.isEmpty) throw _BadInput('There is no ${r.name} to remove.');
    return Batch('Delete ${r.name}', [
      for (final a in items) RemoveAudio(a.id),
    ]);
  }

  EditCommand _setVoiceEffect(Map<String, dynamic> input, Project project) {
    final target = _string(input, 'target');
    bool? flag(String key) {
      final v = input[key];
      if (v == null) return null;
      if (v is! bool) throw _BadInput('"$key" must be true or false.');
      return v;
    }

    VoiceEffect merged(VoiceEffect current) {
      if (flag('reset') ?? false) return VoiceEffect.none;
      var e = current;
      final preset = input['preset'];
      if (preset != null) {
        if (preset is! String ||
            !VoicePreset.values.any((p) => p.name == preset)) {
          throw _BadInput(
            '"preset" must be one of: '
            '${VoicePreset.values.map((p) => p.name).join(', ')}.',
          );
        }
        final p = VoicePreset.values.byName(preset).effect;
        e = e.copyWith(pitch: p.pitch, robot: p.robot);
      }
      if (input.containsKey('pitch')) {
        e = e.copyWith(pitch: _number(input, 'pitch', -12, 12));
      }
      if (input.containsKey('speed')) {
        e = e.copyWith(speed: _number(input, 'speed', 0.5, 2));
      }
      e = e.copyWith(
        robot: flag('robot') ?? e.robot,
        denoise: flag('denoise') ?? e.denoise,
        normalize: flag('normalize') ?? e.normalize,
      );
      return e;
    }

    final audio = project.audio.where((a) => a.id == target).firstOrNull;
    if (audio != null) {
      return UpdateAudio(audio.id, effect: merged(audio.effect));
    }
    if (target == 'video') {
      if (project.clips.isEmpty) throw _BadInput('There are no clips.');
      return SetClipEffect(merged(project.clips.first.effect));
    }
    final clip = project.clips.where((c) => c.id == target).firstOrNull;
    if (clip == null) {
      throw _BadInput(
        '"target" must be "video", a clip_id or an audio_id; "$target" is '
        'none of those.',
      );
    }
    return SetClipEffect(merged(clip.effect), clipIds: [clip.id]);
  }

  Future<EditCommand> _addVoiceover(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final make = context.voiceover;
    if (make == null) throw _BadInput('Voiceovers aren\'t available here.');
    final raw = input['lines'];
    if (raw is! List || raw.isEmpty) {
      throw _BadInput('"lines" must be a list of 1 to 20 lines.');
    }
    final lines = <ScriptLine>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        throw _BadInput('Each line must be an object with "text".');
      }
      final text = _string(item, 'text');
      Duration? start;
      if (item.containsKey('phrase') || item.containsKey('start')) {
        start = _memeStart(item, context);
      }
      lines.add((text: text, start: start));
    }
    final engine = VoiceEngine.values.byName(
      _enum(input, 'engine', [
        for (final e in VoiceEngine.values) e.name,
      ], VoiceEngine.system.name),
    );
    final voice = input['voice'];
    if (voice != null && voice is! String) {
      throw _BadInput('"voice" must be a string.');
    }
    if (engine == VoiceEngine.groq &&
        voice != null &&
        !groqVoices.contains(voice)) {
      throw _BadInput('Groq voices are: ${groqVoices.join(', ')}.');
    }
    final speed = input.containsKey('speed')
        ? _number(input, 'speed', 0.75, 1.5)
        : 1.0;
    try {
      final commands = await make(
        project,
        lines,
        engine,
        (voice as String?) ?? '',
        speed,
        context.playhead,
      );
      return Batch('AI voiceover', commands);
    } on SpeechException catch (e) {
      throw _BadInput(e.message);
    }
  }

  Future<EditCommand> _remakeLine(
    Map<String, dynamic> input,
    Project project,
    ToolContext context,
  ) async {
    final remake = context.remakeLine;
    if (remake == null) throw _BadInput('Voiceovers aren\'t available here.');
    final id = _string(input, 'audio_id');
    final item = project.audio.where((a) => a.id == id).firstOrNull;
    final spec = item == null ? null : project.mediaById(item.mediaId)?.speech;
    if (spec == null) {
      throw _BadInput('"$id" isn\'t a generated voiceover line.');
    }
    final voice = input['voice'];
    if (voice != null && voice is! String) {
      throw _BadInput('"voice" must be a string.');
    }
    try {
      return await remake(
        project,
        id,
        spec.copyWith(
          text: input.containsKey('text') ? _string(input, 'text') : spec.text,
          voice: (voice as String?) ?? spec.voice,
          speed: input.containsKey('speed')
              ? _number(input, 'speed', 0.75, 1.5)
              : spec.speed,
        ),
      );
    } on SpeechException catch (e) {
      throw _BadInput(e.message);
    }
  }

  /// Checks `fields` against the template: known keys, valid colours and
  /// fonts.
  Map<String, String>? _fields(
    Map<String, dynamic> input,
    TitleTemplate template,
    Project project,
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
      if (field.kind == FieldKind.image) {
        if (value.isEmpty) {
          out[key] = '';
          continue;
        }
        final aliases = imageAliases(project);
        final media =
            aliases[value.trim().toLowerCase()] ??
            project.media
                .where(
                  (m) =>
                      m.kind == MediaKind.image &&
                      (m.id == value || m.path == value),
                )
                .firstOrNull;
        if (media == null) {
          throw _BadInput(
            aliases.isEmpty
                ? 'There are no pictures yet. Ask the user to attach one.'
                : 'Field "$key" must be one of: '
                      '${aliases.keys.join(', ')}.',
          );
        }
        out[key] = media.path;
        continue;
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
