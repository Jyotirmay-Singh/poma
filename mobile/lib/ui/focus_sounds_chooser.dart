import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/app_controller.dart';
import '../application/focus_audio_coordinator.dart';
import '../application/focus_audio_ports.dart';
import '../domain/focus_sound_preferences.dart';
import 'copy.dart';
import 'design_tokens.dart';
import 'desktop_scope.dart';

/// The route owns preview cancellation, never the application audio service.
Future<void> showFocusSoundsChooser(
  BuildContext context,
  AppController controller,
  FocusNode opener, {
  FocusNode? fallbackFocus,
}) async {
  final audio = controller.focusAudio;
  if (audio == null) return;
  final owner = _PreviewOwner(audio);
  final fallback = FocusScope.of(context);
  final reduced = MediaQuery.disableAnimationsOf(context);
  Widget content(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textButtonTheme: TextButtonThemeData(
        style: Theme.of(
          context,
        ).textButtonTheme.style?.merge(focusSoundsButtonStyle(context)),
      ),
    ),
    child: _SoundChooser(controller: controller, owner: owner),
  );
  try {
    if (DesktopScope.maybeOf(context) != null) {
      await showDialog<void>(
        context: context,
        requestFocus: true,
        animationStyle: reduced ? AnimationStyle.noAnimation : null,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(PomaSpace.md),
          constraints: const BoxConstraints(maxWidth: 560),
          child: content(context),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight:
              (MediaQuery.sizeOf(context).height -
                  MediaQuery.viewPaddingOf(context).vertical) *
              .9,
        ),
        useSafeArea: true,
        requestFocus: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PomaLayout.panelRadius),
          ),
        ),
        sheetAnimationStyle: reduced ? AnimationStyle.noAnimation : null,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight:
                (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewPaddingOf(context).vertical) *
                .9,
          ),
          child: SafeArea(top: false, child: content(context)),
        ),
      );
    }
  } finally {
    await owner.close();
    if (opener.context != null) {
      opener.requestFocus();
    } else if (fallbackFocus?.context != null) {
      fallbackFocus!.requestFocus();
    } else if (fallback.context != null) {
      fallback.requestFocus();
    }
  }
}

ButtonStyle focusSoundsButtonStyle(BuildContext context) => ButtonStyle(
  side: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.focused)
        ? BorderSide(color: Theme.of(context).colorScheme.onSurface, width: 2)
        : BorderSide.none,
  ),
);

class _PreviewOwner {
  _PreviewOwner(this.audio);
  final FocusAudioCoordinator audio;
  int? token;
  int request = 0;
  bool closed = false;
  Future<void> start(Future<int?> Function() action) async {
    final revision = ++request;
    final next = await action();
    if (closed || revision != request) {
      if (next != null) await audio.dismissPreview(next);
    } else {
      token = next;
    }
  }

  Future<void> stop() async {
    request++;
    final previous = token;
    token = null;
    if (previous != null) await audio.dismissPreview(previous);
    audio.flushPreferences();
  }

  Future<void> close() async {
    closed = true;
    await stop();
  }
}

class _SoundChooser extends StatefulWidget {
  const _SoundChooser({required this.controller, required this.owner});
  final AppController controller;
  final _PreviewOwner owner;
  @override
  State<_SoundChooser> createState() => _SoundChooserState();
}

class _SoundChooserState extends State<_SoundChooser> {
  late final _nodes = {
    for (final sound in FocusSoundId.values) sound: FocusNode(),
  };
  late final _keys = {
    for (final sound in FocusSoundId.values) sound: GlobalKey(),
  };
  final _scope = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  bool _dragging = false;
  FocusSoundId? _focusedSound;
  late final _volumeFocus = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        final value = audio.preferences.volume;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final next = switch (event.logicalKey) {
          LogicalKeyboardKey.home => 0.0,
          LogicalKeyboardKey.end => 1.0,
          LogicalKeyboardKey.arrowUp => value + .01,
          LogicalKeyboardKey.arrowDown => value - .01,
          LogicalKeyboardKey.arrowLeft => value + (rtl ? .01 : -.01),
          LogicalKeyboardKey.arrowRight => value + (rtl ? -.01 : .01),
          _ => null,
        };
        if (next != null) {
          audio.setVolume(next, keyboard: true);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
  );
  FocusAudioCoordinator get audio => widget.owner.audio;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sound = audio.preferences.sound;
      _nodes[sound]!.requestFocus();
      final target = _keys[sound]!.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(widget.owner.close());
    for (final node in _nodes.values) {
      node.dispose();
    }
    _scope.dispose();
    _volumeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusScope(
    node: _scope,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: ListenableBuilder(
        listenable: Listenable.merge([audio, widget.controller]),
        builder: (context, _) {
          final copy = context.copy;
          final state = audio.state;
          final preferences = state.preferences;
          final timer = widget.controller.timer;
          final previewAllowed =
              state.availability == FocusAudioAvailability.available &&
              preferences.volume > 0 &&
              !state.routeBlocked &&
              !state.interrupted &&
              !state.suspended &&
              !state.canRetry &&
              widget.controller.clockError == null;
          final status = focusSoundStatus(
            copy,
            state,
            timer.phase,
            timer.status,
          );
          final percent = (preferences.volume * 100).round();
          return FocusTraversalGroup(
            child: SingleChildScrollView(
              key: const Key('sound-chooser-scroll'),
              padding: const EdgeInsets.all(PomaSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: PomaSpace.sm,
                    children: [
                      Semantics(
                        header: true,
                        namesRoute: true,
                        child: Text(
                          copy.focusSounds,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        key: const Key('sound-close'),
                        onPressed: () => Navigator.pop(context),
                        child: Text(copy.soundClose),
                      ),
                    ],
                  ),
                  Text(copy.soundOnlyFocus),
                  const SizedBox(height: PomaSpace.xs),
                  Text(
                    focusSoundName(copy, preferences.sound),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (status != focusSoundName(copy, preferences.sound))
                    Semantics(
                      liveRegion: state.canRetry,
                      child: Text(
                        status,
                        key: const Key('sound-chooser-status'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: PomaSpace.md),
                  RadioGroup<FocusSoundId>(
                    groupValue: preferences.sound,
                    onChanged: (sound) {
                      if (sound != null) audio.selectSound(sound);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _option(FocusSoundId.off, previewAllowed),
                        const SizedBox(height: PomaSpace.sm),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns =
                                constraints.maxWidth >= 480 &&
                                    MediaQuery.textScalerOf(context).scale(1) <=
                                        1.25
                                ? 2
                                : 1;
                            final width =
                                (constraints.maxWidth -
                                    PomaSpace.sm * (columns - 1)) /
                                columns;
                            return Wrap(
                              spacing: PomaSpace.sm,
                              runSpacing: PomaSpace.sm,
                              children: [
                                for (final sound in FocusSoundId.values.skip(1))
                                  SizedBox(
                                    width: width,
                                    child: _option(sound, previewAllowed),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PomaSpace.lg),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        copy.soundVolume,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(copy.soundPercent(percent)),
                    ],
                  ),
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.home): () =>
                          audio.setVolume(0, keyboard: true),
                      const SingleActivator(LogicalKeyboardKey.end): () =>
                          audio.setVolume(1, keyboard: true),
                    },
                    child: Semantics(
                      label: copy.soundVolumeLabel,
                      child: Listener(
                        onPointerDown: (_) => _dragging = true,
                        onPointerUp: (_) {
                          _dragging = false;
                          audio.flushPreferences();
                        },
                        onPointerCancel: (_) {
                          _dragging = false;
                          audio.flushPreferences();
                        },
                        child: Slider(
                          focusNode: _volumeFocus,
                          key: const Key('sound-volume'),
                          value: preferences.volume,
                          divisions: 100,
                          semanticFormatterCallback: (value) =>
                              copy.soundPercentLabel((value * 100).round()),
                          onChangeStart: (_) {
                            _volumeFocus.requestFocus();
                          },
                          onChanged: (value) =>
                              audio.setVolume(value, keyboard: !_dragging),
                          onChangeEnd: (value) {
                            audio.setVolume(
                              value,
                              commit: _dragging,
                              keyboard: !_dragging,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SwitchListTile.adaptive(
                    key: const Key('sound-mute'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(copy.soundMute),
                    value: preferences.muted,
                    onChanged: audio.setMuted,
                  ),
                  if (state.canRetry)
                    OutlinedButton(
                      key: const Key('sound-retry'),
                      onPressed: () => widget.owner.start(audio.retry),
                      child: Text(copy.soundRetry),
                    )
                  else if (state.previewSound == null &&
                      focusSoundCanPlay(widget.controller, state))
                    OutlinedButton(
                      key: const Key('sound-playback'),
                      onPressed:
                          state.transport == FocusAudioTransport.playing ||
                              state.transport == FocusAudioTransport.loading
                          ? audio.pauseSounds
                          : audio.playSounds,
                      child: Text(
                        state.transport == FocusAudioTransport.playing ||
                                state.transport == FocusAudioTransport.loading
                            ? copy.soundPause
                            : copy.soundPlay,
                      ),
                    ),
                  const SizedBox(height: PomaSpace.md),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: const Key('sound-done'),
                      onPressed: () => Navigator.pop(context),
                      child: Text(copy.soundDone),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _option(FocusSoundId sound, bool allowed) {
    final copy = context.copy;
    final colors = Theme.of(context).colorScheme;
    final selected = audio.preferences.sound == sound;
    final preview = audio.state.previewSound == sound;
    final name = focusSoundName(copy, sound);
    final detail = switch (sound) {
      FocusSoundId.off => null,
      FocusSoundId.tibetanBells => copy.soundBellsDetail,
      FocusSoundId.waterfall => copy.soundWaterfallDetail,
      FocusSoundId.oceanWaves => copy.soundOceanDetail,
      FocusSoundId.forestBirds => copy.soundBirdsDetail,
      FocusSoundId.calmingRain => copy.soundRainDetail,
      FocusSoundId.omChanting => null,
    };
    final icon = switch (sound) {
      FocusSoundId.off => Icons.volume_off_outlined,
      FocusSoundId.tibetanBells => Icons.notifications_none,
      FocusSoundId.waterfall => Icons.water_drop_outlined,
      FocusSoundId.oceanWaves => Icons.waves_outlined,
      FocusSoundId.forestBirds => Icons.forest_outlined,
      FocusSoundId.calmingRain => Icons.grain,
      FocusSoundId.omChanting => Icons.self_improvement,
    };
    return Material(
      key: _keys[sound],
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
        side: BorderSide(
          color: _focusedSound == sound
              ? colors.onSurface
              : selected
              ? colors.primary
              : colors.outline,
          width: selected || _focusedSound == sound ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioListTile<FocusSoundId>(
            onFocusChange: (focused) =>
                setState(() => _focusedSound = focused ? sound : null),
            key: Key('sound-select-${sound.name}'),
            focusNode: _nodes[sound],
            value: sound,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: PomaSpace.xs,
              vertical: PomaSpace.xs,
            ),
            title: Text(name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (detail != null) Text(detail),
                if (selected || sound != FocusSoundId.off)
                  Text(
                    selected ? copy.soundSelected : '',
                    style: TextStyle(color: colors.primary),
                  ),
              ],
            ),
            secondary: ExcludeSemantics(
              child: Icon(icon, color: colors.onSurfaceVariant),
            ),
          ),
          if (sound != FocusSoundId.off)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PomaSpace.xs,
                0,
                PomaSpace.xs,
                PomaSpace.xs,
              ),
              child: Semantics(
                label: preview
                    ? copy.soundStopPreviewLabel(name)
                    : copy.soundPreviewLabel(name),
                excludeSemantics: true,
                button: true,
                enabled: preview || allowed,
                onTap: preview
                    ? widget.owner.stop
                    : allowed
                    ? () => widget.owner.start(() => audio.preview(sound))
                    : null,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    disabledForegroundColor: colors.onSurfaceVariant,
                  ),
                  key: Key('sound-preview-${sound.name}'),
                  onPressed: preview
                      ? widget.owner.stop
                      : allowed
                      ? () => widget.owner.start(() => audio.preview(sound))
                      : null,
                  icon: Icon(preview ? Icons.stop : Icons.play_arrow_outlined),
                  label: Text(
                    preview ? copy.soundStopPreview : copy.soundPreview,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
