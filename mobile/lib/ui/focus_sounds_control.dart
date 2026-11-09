import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../application/focus_audio_ports.dart';
import '../domain/focus_sound_preferences.dart';
import 'copy.dart';
import 'design_tokens.dart';
import 'focus_sounds_chooser.dart';

class FocusSoundsControl extends StatefulWidget {
  const FocusSoundsControl({
    required this.controller,
    this.fallbackFocus,
    super.key,
  });
  final AppController controller;
  final FocusNode? fallbackFocus;
  @override
  State<FocusSoundsControl> createState() => _FocusSoundsControlState();
}

class _FocusSoundsControlState extends State<FocusSoundsControl> {
  final _opener = FocusNode();
  bool _open = false;
  @override
  void dispose() {
    _opener.dispose();
    super.dispose();
  }

  Future<void> _show() async {
    if (_open) return;
    _open = true;
    try {
      await showFocusSoundsChooser(
        context,
        widget.controller,
        _opener,
        fallbackFocus: widget.fallbackFocus,
      );
    } finally {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.controller.focusAudio;
    if (audio == null) return const SizedBox.shrink();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ListenableBuilder(
          listenable: audio,
          builder: (context, _) {
            final copy = context.copy;
            final state = audio.state;
            final colors = Theme.of(context).colorScheme;
            final timer = widget.controller.timer;
            final status = focusSoundStatus(
              copy,
              state,
              timer.phase,
              timer.status,
            );
            final open = TextButton(
              key: const Key('focus-sounds-open'),
              focusNode: _opener,
              onPressed: _show,
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurface,
                alignment: AlignmentDirectional.centerStart,
              ).merge(focusSoundsButtonStyle(context)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.focusSounds,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: PomaSpace.xxs),
                        Text(
                          focusSoundName(copy, state.preferences.sound),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (status !=
                            focusSoundName(copy, state.preferences.sound))
                          Semantics(
                            liveRegion: state.canRetry,
                            child: Text(
                              status,
                              key: const Key('sound-compact-status'),
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const ExcludeSemantics(child: Icon(Icons.expand_more)),
                ],
              ),
            );
            final mute = TextButton(
              style: focusSoundsButtonStyle(context),
              key: const Key('sound-compact-mute'),
              onPressed: () => audio.setMuted(!state.preferences.muted),
              child: Text(
                state.preferences.muted ? copy.soundUnmute : copy.soundMute,
              ),
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: PomaSpace.lg),
              child: Material(
                color: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
                  side: BorderSide(color: colors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.preferences.sound == FocusSoundId.off)
                      open
                    else if (MediaQuery.textScalerOf(context).scale(1) >
                        1.4) ...[
                      open,
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PomaSpace.xs,
                        ),
                        child: mute,
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(child: open),
                          mute,
                        ],
                      ),
                    if (state.canRetry)
                      TextButton(
                        key: const Key('sound-compact-retry'),
                        onPressed: audio.retry,
                        child: Text(copy.soundRetry),
                      )
                    else if (state.transport == FocusAudioTransport.stopped &&
                        state.previewSound == null &&
                        focusSoundCanPlay(widget.controller, state))
                      TextButton(
                        key: const Key('sound-compact-play'),
                        onPressed: audio.playSounds,
                        child: Text(copy.soundPlay),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
