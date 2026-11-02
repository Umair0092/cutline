import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/project_library.dart';
import '../timeline/timeline_painter.dart';
import '../timeline/timeline_panel.dart';
import 'app_menu.dart';
import 'compact_editor.dart';
import 'editor/editor_title_bar.dart';
import 'editor/resize_divider.dart';
import 'editor_shortcuts.dart';
import 'file_actions.dart';
import 'preview_pane.dart';
import 'sidebar.dart';
import 'tokens.dart';
import 'transcript_panel.dart';

export 'editor/editor_title_bar.dart' show ProjectTitleBar;

/// The main editor window: the title bar on top, the preview with the
/// timeline under it on the left, and the sidebar down the right.
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autosaveProvider);
    // Back (button, gesture or Esc) goes to the dashboard via leaveEditor,
    // which saves first.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leaveEditor(ref, context);
      },
      child: isCompact(context) ? const CompactEditor() : const _WideEditor(),
    );
  }
}

/// Asks to save changes to a project kept outside the library before
/// leaving it. Returns false if the user cancelled.
Future<bool> confirmLeave(WidgetRef ref, BuildContext context) =>
    FileActions(ref, context).confirmDiscard();

class _WideEditor extends StatefulWidget {
  const _WideEditor();

  @override
  State<_WideEditor> createState() => _WideEditorState();
}

class _WideEditorState extends State<_WideEditor> {
  static const _toolbar = 40.0;

  /// Just enough for every track row, and the default.
  static const minTimeline = TimelineRows.height + _toolbar + 14;

  /// Survives leaving and reopening the editor in one session.
  static double? _remembered;

  double _timeline = _remembered ?? minTimeline;

  double _sidebarWidth(double width) =>
      (width * 0.27).clamp(340.0, 420.0).toDouble();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cut.base,
      body: AutoTranscribe(
        child: EditorShortcuts(
          child: Column(
            children: [
              const ProjectTitleBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // The preview always keeps at least 200 px.
                    final max = (box.maxHeight - 200).clamp(
                      minTimeline,
                      double.infinity,
                    );
                    final timeline = _timeline.clamp(minTimeline, max);
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Expanded(
                                child: PreviewPane(key: Key('preview')),
                              ),
                              ResizeDivider(
                                onDrag: (dy) => setState(() {
                                  _timeline = _remembered = (timeline - dy)
                                      .clamp(minTimeline, max);
                                }),
                                onReset: () => setState(
                                  () => _timeline = _remembered = minTimeline,
                                ),
                              ),
                              SizedBox(
                                height: timeline,
                                child: const TimelinePanel(
                                  key: Key('timeline'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: _sidebarWidth(box.maxWidth),
                          decoration: const BoxDecoration(
                            color: Cut.surface1,
                            border: Border(
                              left: BorderSide(color: Cut.strokeSubtle),
                            ),
                          ),
                          child: const Sidebar(key: Key('sidebar')),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
