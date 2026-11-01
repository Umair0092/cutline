# Roadmap

## The core idea

The project is a plain data model: source media, tracks, clips, overlays, audio and effects. The timeline UI edits that model through commands (so undo/redo works), and the AI edits it through the same commands, exposed as tools. The AI never touches pixels directly. It says "insert intro template `bold-title` at 0s with name = Umair", and the app does the rest.

Because the AI's changes are ordinary edits, you can always open the inspector and change the intro text, move the meme, or undo the whole thing.

To let the AI understand "when I talk about deadlines", the video is transcribed on-device with word-level timestamps, and that transcript is part of what the AI sees.

## Stack

| Part | Choice | Why |
|---|---|---|
| App | Swift + SwiftUI, macOS 14+ | Native feel, good performance on Apple Silicon |
| Video | AVFoundation (AVMutableComposition, AVVideoComposition, Core Animation for titles) | Built in, hardware accelerated, no FFmpeg bundling |
| AI | Claude API with tool use, key stored in Keychain | Turns plain language into structured edit commands |
| Transcription | WhisperKit (on-device) | Free, private, gives word timestamps |
| Memes | GIPHY API + a local memes folder | Search by name, or use your own |
| Voice | AVAudioEngine (record, pitch), a TTS provider for AI voiceover | Pitch shift is built in; TTS provider is decided in #15 |

## Milestones

1. **Foundation**: project setup, project model, import and playback, timeline, export
2. **AI assistant**: chat panel, edit tools, transcription
3. **Intros**: intro templates, AI intros
4. **Memes and overlays**: overlay track, meme search, AI meme placement
5. **Voice**: record voiceover, AI voiceover, pitch and voice effects, voice changer
6. **Release**: packaging and onboarding

Open questions we'll settle while building (voice changer provider, TTS provider, pricing of API calls) are noted in the related issues.
