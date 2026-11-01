# Roadmap

## The core idea

The project is a plain data model: source media, tracks, clips, overlays, audio and effects. The timeline UI edits that model through commands (so undo/redo works), and the AI edits it through the same commands, exposed as tools. The AI never touches pixels directly. It says "insert intro template `bold-title` at 0s with name = Umair", and the app does the rest.

Because the AI's changes are ordinary edits, you can always open the inspector and change the intro text, move the meme, or undo the whole thing.

To let the AI understand "when I talk about deadlines", the video is transcribed on-device with word-level timestamps, and that transcript is part of what the AI sees.

## Stack

One codebase for macOS, Windows and iOS. Desktop comes first, iOS after the desktop app works.

| Part | Choice | Why |
|---|---|---|
| App | Flutter (Dart) | One codebase builds real apps for macOS, Windows, iOS (and Android if we want it later). Mature on mobile, compiles to native code |
| State | Riverpod | Simple, testable |
| Preview | media_kit (libmpv) | Same player on every platform, supports audio filters for live pitch preview |
| Export | FFmpeg, bundled on desktop | One export pipeline for Mac and Windows. iOS needs a different route, see #19 |
| Titles and overlays | Flutter widgets, rendered to frames for export | The same code draws the preview and the export, so they match |
| AI | Claude API with tool use, key in secure storage | Turns plain language into structured edit commands |
| Transcription | whisper.cpp (on-device) | Runs on Mac, Windows and iOS, free, private, gives word timestamps |
| Memes | GIPHY API + a local memes folder | Search by name, or use your own |
| Voice | `record` package, FFmpeg/mpv `rubberband` for pitch, a TTS provider for AI voiceover | TTS provider is decided in #15 |

### Why Flutter

- **Tauri** (web UI + Rust) is a good desktop option, but its iOS support is newer and video work there is mostly uncharted.
- **Electron** has no iOS.
- **Native apps per platform** (SwiftUI + C#/WinUI) give the best feel but mean writing the app two or three times.

Flutter is the one option that's solid on all three targets today. The tricky part is export on iOS, which is planned as its own issue.

## Milestones

1. **Foundation**: project setup, project model, import and playback, timeline, export
2. **AI assistant**: chat panel, edit tools, transcription
3. **Intros**: intro templates, AI intros
4. **Memes and overlays**: overlay track, meme search, AI meme placement
5. **Voice**: record voiceover, AI voiceover, pitch and voice effects, voice changer
6. **Release**: packaging and onboarding for macOS and Windows
7. **iOS**: phone and tablet layout, iOS export

Open questions we'll settle while building (voice changer provider, TTS provider, pricing of API calls) are noted in the related issues.
