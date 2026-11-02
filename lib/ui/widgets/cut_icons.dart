import 'package:flutter/widgets.dart';

/// The app's icons (Phosphor, MIT; the fonts are in assets/fonts/phosphor),
/// by what they mean, so every screen uses the same
/// picture for the same idea. Phosphor Regular at rest, Fill when active.
abstract final class CutIcons {
  // AI
  static const ai = IconData(0xe6a2, fontFamily: 'PhosphorFill');
  static const aiOutline = IconData(0xe6a2, fontFamily: 'PhosphorRegular');
  static const magic = IconData(0xe6b6, fontFamily: 'PhosphorRegular');

  // Navigation and files
  static const home = IconData(0xe2c2, fontFamily: 'PhosphorRegular');
  static const homeFill = IconData(0xe2c2, fontFamily: 'PhosphorFill');
  static const back = IconData(0xe138, fontFamily: 'PhosphorRegular');
  static const forward = IconData(0xe13a, fontFamily: 'PhosphorRegular');
  static const down = IconData(0xe136, fontFamily: 'PhosphorRegular');
  static const up = IconData(0xe13c, fontFamily: 'PhosphorRegular');
  static const close = IconData(0xe4f6, fontFamily: 'PhosphorRegular');
  static const more = IconData(0xe1fe, fontFamily: 'PhosphorRegular');
  static const moreVertical = IconData(0xe208, fontFamily: 'PhosphorRegular');
  static const settings = IconData(0xe272, fontFamily: 'PhosphorRegular');
  static const search = IconData(0xe30c, fontFamily: 'PhosphorRegular');
  static const folder = IconData(0xe256, fontFamily: 'PhosphorRegular');
  static const file = IconData(0xe230, fontFamily: 'PhosphorRegular');
  static const add = IconData(0xe3d4, fontFamily: 'PhosphorRegular');
  static const addCircle = IconData(0xe3d6, fontFamily: 'PhosphorRegular');
  static const check = IconData(0xe182, fontFamily: 'PhosphorBold');
  static const checkCircle = IconData(0xe184, fontFamily: 'PhosphorFill');
  static const info = IconData(0xe2ce, fontFamily: 'PhosphorRegular');
  static const warning = IconData(0xe4e0, fontFamily: 'PhosphorRegular');
  static const error = IconData(0xe4e2, fontFamily: 'PhosphorRegular');
  static const trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular');
  static const rename = IconData(0xe3b4, fontFamily: 'PhosphorRegular');
  static const copy = IconData(0xe1ca, fontFamily: 'PhosphorRegular');
  static const duplicate = IconData(0xe1cc, fontFamily: 'PhosphorRegular');
  static const export = IconData(0xeaf0, fontFamily: 'PhosphorRegular');
  static const download = IconData(0xe20c, fontFamily: 'PhosphorRegular');
  static const upload = IconData(0xe4c0, fontFamily: 'PhosphorRegular');
  static const share = IconData(0xe408, fontFamily: 'PhosphorRegular');
  static const lock = IconData(0xe308, fontFamily: 'PhosphorRegular');
  static const key = IconData(0xe2d6, fontFamily: 'PhosphorRegular');
  static const eye = IconData(0xe220, fontFamily: 'PhosphorRegular');
  static const eyeOff = IconData(0xe224, fontFamily: 'PhosphorRegular');
  static const keyboard = IconData(0xe2d8, fontFamily: 'PhosphorRegular');
  static const help = IconData(0xe3e8, fontFamily: 'PhosphorRegular');
  static const clock = IconData(0xe19a, fontFamily: 'PhosphorRegular');
  static const sort = IconData(0xe444, fontFamily: 'PhosphorRegular');
  static const grid = IconData(0xe464, fontFamily: 'PhosphorRegular');
  static const list = IconData(0xe2f0, fontFamily: 'PhosphorRegular');

  // Editing
  static const undo = IconData(0xe038, fontFamily: 'PhosphorRegular');
  static const redo = IconData(0xe036, fontFamily: 'PhosphorRegular');
  static const split = IconData(0xeae0, fontFamily: 'PhosphorRegular');
  static const cut = IconData(0xeae0, fontFamily: 'PhosphorRegular');
  static const trim = IconData(0xe85e, fontFamily: 'PhosphorRegular');
  static const text = IconData(0xe48a, fontFamily: 'PhosphorRegular');
  static const textStyle = IconData(0xe6ee, fontFamily: 'PhosphorRegular');
  static const title = IconData(0xe48a, fontFamily: 'PhosphorRegular');
  static const intro = IconData(0xe8c2, fontFamily: 'PhosphorRegular');
  static const meme = IconData(0xe436, fontFamily: 'PhosphorRegular');
  static const sticker = IconData(0xe5ac, fontFamily: 'PhosphorRegular');
  static const image = IconData(0xe2ca, fontFamily: 'PhosphorRegular');
  static const addImage = IconData(0xe2cc, fontFamily: 'PhosphorRegular');
  static const attach = IconData(0xe39a, fontFamily: 'PhosphorRegular');
  static const video = IconData(0xe792, fontFamily: 'PhosphorRegular');
  static const film = IconData(0xe8c0, fontFamily: 'PhosphorRegular');
  static const transcript = IconData(0xe0a8, fontFamily: 'PhosphorRegular');
  static const layers = IconData(0xe466, fontFamily: 'PhosphorRegular');
  static const palette = IconData(0xe6c8, fontFamily: 'PhosphorRegular');
  static const zoomIn = IconData(0xe310, fontFamily: 'PhosphorRegular');
  static const zoomOut = IconData(0xe30e, fontFamily: 'PhosphorRegular');
  static const fit = IconData(0xe530, fontFamily: 'PhosphorRegular');
  static const fullscreen = IconData(0xe1d0, fontFamily: 'PhosphorRegular');

  // Playback
  static const play = IconData(0xe3d0, fontFamily: 'PhosphorFill');
  static const pause = IconData(0xe39e, fontFamily: 'PhosphorFill');
  static const stop = IconData(0xe46c, fontFamily: 'PhosphorFill');
  static const skipBack = IconData(0xe5a4, fontFamily: 'PhosphorFill');
  static const skipForward = IconData(0xe5a6, fontFamily: 'PhosphorFill');
  static const toStart = IconData(0xe6a8, fontFamily: 'PhosphorRegular');
  static const playCircle = IconData(0xe3d2, fontFamily: 'PhosphorFill');
  static const stopCircle = IconData(0xe46e, fontFamily: 'PhosphorFill');

  // Audio
  static const audio = IconData(0xe802, fontFamily: 'PhosphorRegular');
  static const music = IconData(0xe340, fontFamily: 'PhosphorRegular');
  static const musicLibrary = IconData(0xeb7c, fontFamily: 'PhosphorRegular');
  static const sound = IconData(0xe450, fontFamily: 'PhosphorRegular');
  static const volume = IconData(0xe44a, fontFamily: 'PhosphorRegular');
  static const mute = IconData(0xe456, fontFamily: 'PhosphorRegular');
  static const mic = IconData(0xe326, fontFamily: 'PhosphorRegular');
  static const micFill = IconData(0xe326, fontFamily: 'PhosphorFill');
  static const record = IconData(0xe3ee, fontFamily: 'PhosphorFill');
  static const voice = IconData(0xeca8, fontFamily: 'PhosphorRegular');
  static const voiceEffect = IconData(0xea9a, fontFamily: 'PhosphorRegular');
  static const levels = IconData(0xe434, fontFamily: 'PhosphorRegular');
  static const person = IconData(0xe4c2, fontFamily: 'PhosphorRegular');

  // Chat
  static const send = IconData(0xe08e, fontFamily: 'PhosphorBold');
  static const chat = IconData(0xe16e, fontFamily: 'PhosphorRegular');

  // Editor (preview, timeline, inspectors)
  static const ambient = IconData(0xe472, fontFamily: 'PhosphorRegular');
  static const ambientFill = IconData(0xe472, fontFamily: 'PhosphorFill');
  static const opacity = IconData(0xe210, fontFamily: 'PhosphorRegular');
  static const rotate = IconData(0xe036, fontFamily: 'PhosphorRegular');
  static const fadeIn = IconData(0xe4ae, fontFamily: 'PhosphorRegular');
  static const fadeOut = IconData(0xe4ac, fontFamily: 'PhosphorRegular');
  static const pitch = IconData(0xe098, fontFamily: 'PhosphorRegular');
  static const speed = IconData(0xe628, fontFamily: 'PhosphorRegular');
  static const animation = IconData(0xe2de, fontFamily: 'PhosphorRegular');
  static const grip = IconData(0xeae2, fontFamily: 'PhosphorRegular');
}

/// Size presets.
abstract final class CutIconSize {
  static const small = 16.0;
  static const desktop = 20.0;
  static const touch = 24.0;
  static const hero = 48.0;
}
