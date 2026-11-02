import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'splash_screen.dart';

/// Adds the licenses of what ships inside the app (FFmpeg, whisper.cpp,
/// the title fonts) to the licenses page, next to the Dart packages'.
void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    Future<String> text(String asset) => rootBundle.loadString(asset);
    yield LicenseEntryWithLineBreaks(
      ['FFmpeg'],
      'Cutline includes FFmpeg (ffmpeg.org), built as LGPL 2.1 without GPL '
      'or non-free parts, as a separate program in the app bundle. Its '
      'source and the build script (tool/build_ffmpeg_macos.sh) are in the '
      'Cutline repository; you can replace the bundled binary with your '
      'own build.\n\n${await text('assets/licenses/ffmpeg-LGPL-2.1.txt')}',
    );
    yield LicenseEntryWithLineBreaks([
      'whisper.cpp',
    ], await text('assets/licenses/whisper.cpp-MIT.txt'));
    yield LicenseEntryWithLineBreaks([
      'Phosphor icons',
    ], await text('assets/fonts/phosphor/Phosphor-MIT.txt'));
    for (final font in [
      'Inter',
      'BebasNeue',
      'PlayfairDisplay',
      'BricolageGrotesque',
      'JetBrainsMono',
    ]) {
      yield LicenseEntryWithLineBreaks([
        '$font font',
      ], await text('assets/fonts/$font-OFL.txt'));
    }
  });
}

Future<void> showCutlineAbout(BuildContext context) async {
  String version;
  try {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version} (${info.buildNumber})';
  } on Object {
    version = '';
  }
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: 'Cutline',
    applicationVersion: version,
    applicationIcon: const CutlineLogo(size: 56),
    children: const [
      SizedBox(height: 12),
      Text('Edit videos by saying what you want.'),
      SizedBox(height: 12),
      Text(
        'Your videos never leave your computer: export uses FFmpeg and '
        'transcripts use whisper.cpp, both on your computer. The assistant '
        'is sent what you type, a summary of the project and its '
        'transcript. Meme searches go to GIPHY, and Groq voices send the '
        'voiceover text to Groq.',
      ),
    ],
  );
}
