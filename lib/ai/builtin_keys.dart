/// Keys built into this copy of the app at build time, so it works without
/// asking for any. They come from `keys.env` (never committed) through
/// `--dart-define-from-file=keys.env`; see tool/build_with_keys.sh.
///
/// Anyone with the built app can dig these out, so only use them in builds
/// you keep for yourself. A key saved in Settings always wins.
const builtinGroqKey = String.fromEnvironment('GROQ_API_KEY');
const builtinGiphyKey = String.fromEnvironment('GIPHY_API_KEY');
const builtinElevenLabsKey = String.fromEnvironment('ELEVENLABS_API_KEY');
