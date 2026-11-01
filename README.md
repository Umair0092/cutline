# Cutline

A video editor for macOS, Windows and iOS where you describe the edit and the app does it. One Flutter codebase for all three.

Tell it "add an intro with my name and the title *Weekly Rails Tips*", "put the 'this is fine' meme where I talk about deadlines", or "lower my voice a little", and Cutline turns that into real edits on the timeline. Every change the AI makes is a normal edit: you can see it, tweak it in the inspector, or undo it.

Status: planning. See [docs/ROADMAP.md](docs/ROADMAP.md) and the [issues](../../issues).

## Planned features

- Import a video, trim and split it on a timeline, export to MP4
- Chat panel that edits the project for you
- Intro templates with editable parts (name, title, colors, logo, length)
- Memes, GIFs and stickers placed at the right moment, found by what you say in the video
- Record a voiceover, or generate one from text
- Change the pitch and tone of your voice

## Stack

- Flutter (Dart), one codebase for macOS, Windows and iOS
- media_kit for playback, FFmpeg for export
- Claude API (tool use) for turning instructions into edits
- whisper.cpp for on-device transcription with word timestamps
