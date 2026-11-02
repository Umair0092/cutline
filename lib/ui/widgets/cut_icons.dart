import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The app's icons, by what they mean, so every screen uses the same
/// picture for the same idea. Phosphor Regular at rest, Fill when active.
abstract final class CutIcons {
  // AI
  static const ai = PhosphorIconsFill.sparkle;
  static const aiOutline = PhosphorIconsRegular.sparkle;
  static const magic = PhosphorIconsRegular.magicWand;

  // Navigation and files
  static const home = PhosphorIconsRegular.house;
  static const homeFill = PhosphorIconsFill.house;
  static const back = PhosphorIconsRegular.caretLeft;
  static const forward = PhosphorIconsRegular.caretRight;
  static const down = PhosphorIconsRegular.caretDown;
  static const up = PhosphorIconsRegular.caretUp;
  static const close = PhosphorIconsRegular.x;
  static const more = PhosphorIconsRegular.dotsThree;
  static const moreVertical = PhosphorIconsRegular.dotsThreeVertical;
  static const settings = PhosphorIconsRegular.gearSix;
  static const search = PhosphorIconsRegular.magnifyingGlass;
  static const folder = PhosphorIconsRegular.folderOpen;
  static const file = PhosphorIconsRegular.file;
  static const add = PhosphorIconsRegular.plus;
  static const addCircle = PhosphorIconsRegular.plusCircle;
  static const check = PhosphorIconsBold.check;
  static const checkCircle = PhosphorIconsFill.checkCircle;
  static const info = PhosphorIconsRegular.info;
  static const warning = PhosphorIconsRegular.warning;
  static const error = PhosphorIconsRegular.warningCircle;
  static const trash = PhosphorIconsRegular.trash;
  static const rename = PhosphorIconsRegular.pencilSimple;
  static const copy = PhosphorIconsRegular.copy;
  static const duplicate = PhosphorIconsRegular.copySimple;
  static const export = PhosphorIconsRegular.export;
  static const download = PhosphorIconsRegular.downloadSimple;
  static const upload = PhosphorIconsRegular.uploadSimple;
  static const share = PhosphorIconsRegular.shareNetwork;
  static const lock = PhosphorIconsRegular.lockSimple;
  static const key = PhosphorIconsRegular.key;
  static const eye = PhosphorIconsRegular.eye;
  static const eyeOff = PhosphorIconsRegular.eyeSlash;
  static const keyboard = PhosphorIconsRegular.keyboard;
  static const help = PhosphorIconsRegular.question;
  static const clock = PhosphorIconsRegular.clock;
  static const sort = PhosphorIconsRegular.sortAscending;
  static const grid = PhosphorIconsRegular.squaresFour;
  static const list = PhosphorIconsRegular.list;

  // Editing
  static const undo = PhosphorIconsRegular.arrowCounterClockwise;
  static const redo = PhosphorIconsRegular.arrowClockwise;
  static const split = PhosphorIconsRegular.scissors;
  static const cut = PhosphorIconsRegular.scissors;
  static const trim = PhosphorIconsRegular.bracketsSquare;
  static const text = PhosphorIconsRegular.textT;
  static const textStyle = PhosphorIconsRegular.textAa;
  static const title = PhosphorIconsRegular.textT;
  static const intro = PhosphorIconsRegular.filmSlate;
  static const meme = PhosphorIconsRegular.smiley;
  static const sticker = PhosphorIconsRegular.sticker;
  static const image = PhosphorIconsRegular.image;
  static const addImage = PhosphorIconsRegular.imageSquare;
  static const attach = PhosphorIconsRegular.paperclip;
  static const video = PhosphorIconsRegular.filmStrip;
  static const film = PhosphorIconsRegular.filmReel;
  static const transcript = PhosphorIconsRegular.article;
  static const layers = PhosphorIconsRegular.stack;
  static const palette = PhosphorIconsRegular.palette;
  static const zoomIn = PhosphorIconsRegular.magnifyingGlassPlus;
  static const zoomOut = PhosphorIconsRegular.magnifyingGlassMinus;
  static const fit = PhosphorIconsRegular.arrowsInLineHorizontal;
  static const fullscreen = PhosphorIconsRegular.cornersOut;

  // Playback
  static const play = PhosphorIconsFill.play;
  static const pause = PhosphorIconsFill.pause;
  static const stop = PhosphorIconsFill.stop;
  static const skipBack = PhosphorIconsFill.skipBack;
  static const skipForward = PhosphorIconsFill.skipForward;
  static const toStart = PhosphorIconsRegular.rewind;
  static const playCircle = PhosphorIconsFill.playCircle;
  static const stopCircle = PhosphorIconsFill.stopCircle;

  // Audio
  static const audio = PhosphorIconsRegular.waveform;
  static const music = PhosphorIconsRegular.musicNotes;
  static const musicLibrary = PhosphorIconsRegular.musicNotesPlus;
  static const sound = PhosphorIconsRegular.speakerSimpleHigh;
  static const volume = PhosphorIconsRegular.speakerHigh;
  static const mute = PhosphorIconsRegular.speakerSimpleSlash;
  static const mic = PhosphorIconsRegular.microphone;
  static const micFill = PhosphorIconsFill.microphone;
  static const record = PhosphorIconsFill.record;
  static const voice = PhosphorIconsRegular.userSound;
  static const voiceEffect = PhosphorIconsRegular.waveSine;
  static const levels = PhosphorIconsRegular.slidersHorizontal;
  static const person = PhosphorIconsRegular.user;

  // Chat
  static const send = PhosphorIconsBold.arrowUp;
  static const chat = PhosphorIconsRegular.chatCircleText;

  // Editor (preview, timeline, inspectors)
  static const ambient = PhosphorIconsRegular.sun;
  static const ambientFill = PhosphorIconsFill.sun;
  static const opacity = PhosphorIconsRegular.drop;
  static const rotate = PhosphorIconsRegular.arrowClockwise;
  static const fadeIn = PhosphorIconsRegular.trendUp;
  static const fadeOut = PhosphorIconsRegular.trendDown;
  static const pitch = PhosphorIconsRegular.arrowsDownUp;
  static const speed = PhosphorIconsRegular.gauge;
  static const animation = PhosphorIconsRegular.lightning;
  static const grip = PhosphorIconsRegular.dotsSixVertical;
  static const saved = PhosphorIconsRegular.checkCircle;
  static const cloud = PhosphorIconsRegular.cloudCheck;
}

/// Size presets.
abstract final class CutIconSize {
  static const small = 16.0;
  static const desktop = 20.0;
  static const touch = 24.0;
  static const hero = 48.0;
}

/// A Phosphor duotone icon with the second tone in the accent colour, for
/// empty states and onboarding. Pass a `PhosphorIconsDuotone` icon.
Widget duotone(
  IconData icon, {
  double size = 56,
  Color? color,
  Color secondary = const Color(0xFF8B6DFF),
}) => PhosphorIcon(
  icon,
  size: size,
  color: color,
  duotoneSecondaryColor: secondary,
  duotoneSecondaryOpacity: 0.4,
);
