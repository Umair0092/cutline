import 'package:flutter/material.dart';

import '../tokens.dart';
import '../widgets/cut_icons.dart';
import '../widgets/cut_widgets.dart';
import 'chat_parts.dart';

/// The chat box: a rounded container that lights up with the aurora when
/// focused and spins it while the AI works. Attach on the left, Send (or
/// Stop) on the right, waiting attachments along the top.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onAttach,
    required this.onSend,
    required this.onStop,
    required this.busy,
    required this.enabled,
    this.footer,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> attachments;
  final ValueChanged<String> onRemoveAttachment;
  final VoidCallback? onAttach;
  final VoidCallback? onSend;
  final VoidCallback onStop;
  final bool busy;
  final bool enabled;

  /// Shown under the box: the model chip and the keyboard hint.
  final Widget? footer;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_sync);
    widget.controller.addListener(_sync);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_sync);
    widget.controller.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    final f = widget.focusNode.hasFocus;
    final t = widget.controller.text.trim().isNotEmpty;
    if (f != _focused || t != _hasText) {
      setState(() {
        _focused = f;
        _hasText = t;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final touch = isTouchPlatform;
    final canSend =
        widget.enabled &&
        !widget.busy &&
        (_hasText || widget.attachments.isNotEmpty);
    const r = CutRadii.xl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuroraBorder(
          radius: r,
          width: 1.5,
          active: widget.busy || _focused,
          spinning: widget.busy,
          opacity: widget.busy ? 1 : 0.7,
          child: AnimatedContainer(
            duration: CutMotion.normal,
            decoration: BoxDecoration(
              color: Cut.surface2,
              borderRadius: BorderRadius.circular(r - 1.5),
              boxShadow: _focused ? CutShadows.e2 : CutShadows.e1,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: CutMotion.normal,
                  curve: CutMotion.decelerate,
                  alignment: Alignment.topCenter,
                  child: widget.attachments.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                          child: PendingAttachments(
                            files: widget.attachments,
                            onRemove: widget.onRemoveAttachment,
                          ),
                        ),
                ),
                TextField(
                  key: const Key('chat-input'),
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  cursorColor: Cut.accent,
                  cursorWidth: 2,
                  cursorRadius: const Radius.circular(1),
                  style: CutType.body.copyWith(
                    fontSize: touch ? 15 : 14,
                    height: touch ? 22 / 15 : 20 / 14,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.busy
                        ? 'Working on it…'
                        : widget.attachments.isNotEmpty
                        ? 'Say what to do with ${widget.attachments.length == 1 ? 'it' : 'them'}…'
                        : 'Ask for an edit, or describe your video…',
                    hintStyle: CutType.body.copyWith(
                      color: Cut.textTertiary,
                      fontSize: touch ? 15 : 14,
                    ),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(
                      14,
                      touch ? 14 : 12,
                      14,
                      touch ? 6 : 4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Row(
                    children: [
                      _RoundButton(
                        key: const Key('chat-attach'),
                        tooltip: 'Attach pictures or audio',
                        icon: CutIcons.add,
                        onTap: widget.onAttach,
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: CutMotion.fast,
                        transitionBuilder: (child, a) => ScaleTransition(
                          scale: Tween(begin: 0.7, end: 1.0).animate(a),
                          child: FadeTransition(opacity: a, child: child),
                        ),
                        child: widget.busy
                            ? _RoundButton(
                                key: const Key('stop'),
                                tooltip: 'Stop',
                                icon: CutIcons.stop,
                                onTap: widget.onStop,
                                filled: Cut.surface4,
                                iconColor: Cut.textPrimary,
                              )
                            : _RoundButton(
                                key: const Key('send'),
                                tooltip: 'Send (Enter)',
                                icon: CutIcons.send,
                                onTap: widget.enabled ? widget.onSend : null,
                                filled: canSend ? Cut.accent : Cut.surface4,
                                iconColor: canSend
                                    ? Colors.white
                                    : Cut.textDisabled,
                                glow: canSend,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ?widget.footer,
      ],
    );
  }
}

class _RoundButton extends StatefulWidget {
  const _RoundButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.filled,
    this.iconColor,
    this.glow = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? filled;
  final Color? iconColor;
  final bool glow;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = isTouchPlatform ? 40.0 : 32.0;
    final enabled = widget.onTap != null;
    final bg =
        widget.filled ?? (_hover && enabled ? Cut.surface4 : Cut.surface3);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Pressable(
          onTap: widget.onTap,
          pressedScale: 0.9,
          semanticLabel: widget.tooltip,
          child: AnimatedContainer(
            duration: CutMotion.fast,
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: widget.filled == null
                  ? Border.all(color: Cut.strokeDefault)
                  : null,
              boxShadow: widget.glow
                  ? const [
                      BoxShadow(
                        color: Color(0x668B6DFF),
                        blurRadius: 14,
                        offset: Offset(0, 4),
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              size: isTouchPlatform ? 19 : 16,
              color:
                  widget.iconColor ??
                  (enabled ? Cut.textSecondary : Cut.textDisabled),
            ),
          ),
        ),
      ),
    );
  }
}
