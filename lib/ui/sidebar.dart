import 'package:flutter/material.dart';

import '../memes/meme_panel.dart';
import 'assistant_panel.dart';
import 'transcript_panel.dart';

/// The right-hand sidebar: the assistant, the transcript and memes, as
/// tabs.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: ColoredBox(
        color: colors.surfaceContainerLow,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(key: Key('tab-assistant'), height: 36, text: 'Assistant'),
                Tab(key: Key('tab-transcript'), height: 36, text: 'Transcript'),
                Tab(key: Key('tab-memes'), height: 36, text: 'Memes'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [AssistantPanel(), TranscriptPanel(), MemePanel()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
