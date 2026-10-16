import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../catalog/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// The playground: one control per knob, in a column. The controls are the
/// package's own (SquishSwitch, RubberSegment, GlideSelect, WakeSlider).
class Playground extends StatelessWidget {
  const Playground({super.key, required this.knobs});

  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: knobs,
      builder: (context, _) {
        final List<Knob<Object?>> all = knobs.all.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Playground', style: AppType.lead(context)),
                ),
                AnimatedOpacity(
                  opacity: knobs.allDefault ? 0 : 1,
                  duration: Motion.fast,
                  child: IgnorePointer(
                    ignoring: knobs.allDefault,
                    child: TextLink(
                      label: 'Reset',
                      onTap: knobs.reset,
                      style: AppType.small(context),
                    ),
                  ),
                ),
              ],
            ),
            for (final Knob<Object?> k in all) ...[
              const SizedBox(height: 22),
              _KnobControl(knob: k, knobs: knobs),
            ],
          ],
        );
      },
    );
  }
}

/// The playground behind a "Show the playground" link, for narrow screens.
class CollapsiblePlayground extends StatefulWidget {
  const CollapsiblePlayground({super.key, required this.knobs});

  final Knobs knobs;

  @override
  State<CollapsiblePlayground> createState() => _CollapsiblePlaygroundState();
}

class _CollapsiblePlaygroundState extends State<CollapsiblePlayground> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextLink(
            label: _open ? 'Hide the playground' : 'Open the playground',
            onTap: () => setState(() => _open = !_open),
            style: AppType.body(context).copyWith(fontWeight: FontWeight.w500),
            restColor: Palette.of(context).ink,
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Playground(knobs: widget.knobs),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _KnobControl extends StatelessWidget {
  const _KnobControl({required this.knob, required this.knobs});

  final Knob<Object?> knob;
  final Knobs knobs;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final TextStyle label = AppFonts.text(
      TextStyle(fontSize: 15.5, height: 1.4, color: p.ink),
    );
    final Object? value = knobs.valueOf(knob.id);
    final Knob<Object?> k = knob;

    Widget help() => k.help == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(k.help!, style: AppType.small(context)),
          );

    if (k is ToggleKnob) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(k.label, style: label)),
              SquishSwitch(
                value: value! as bool,
                size: const Size(44, 26),
                activeColor: p.ink,
                inactiveColor: p.surfaceStrong,
                thumbColor: p.bg,
                enableHaptics: false,
                semanticLabel: k.label,
                onChanged: (v) => knobs.set(k.id, v),
              ),
            ],
          ),
          help(),
        ],
      );
    }

    String? readout;
    if (k is SliderKnob) readout = k.display(value! as double);

    final Widget control = switch (k) {
      SelectKnob() => _SelectControl(knob: k, knobs: knobs, value: value),
      SliderKnob() => WakeSlider(
        value: (value! as double).clamp(k.min, k.max),
        min: k.min,
        max: k.max,
        divisions: k.divisions,
        height: 32,
        bars: 28,
        activeColor: p.ink,
        inactiveColor: p.surfaceStrong,
        semanticLabel: k.label,
        onChanged: (v) => knobs.set(k.id, v),
      ),
      ColorKnob() => _ColorControl(knob: k, knobs: knobs, value: value),
      TextKnob() => _TextControl(knob: k, knobs: knobs),
      _ => const SizedBox.shrink(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(k.label, style: label)),
            if (readout != null)
              Text(
                readout,
                style: label.copyWith(
                  color: p.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        control,
        help(),
      ],
    );
  }
}

class _SelectControl extends StatelessWidget {
  const _SelectControl({
    required this.knob,
    required this.knobs,
    required this.value,
  });

  final SelectKnob<Object?> knob;
  final Knobs knobs;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final List<Object?> options = knob.options;
    final int letters = options.fold<int>(
      0,
      (sum, o) => sum + knob.labelFor(o).length,
    );
    final TextStyle text = AppFonts.text(
      TextStyle(fontSize: 14.5, color: p.ink),
    );
    if (options.length <= 3 && letters <= 22) {
      return Align(
        alignment: Alignment.centerLeft,
        child: RubberSegment<Object?>(
          items: [
            for (final Object? o in options)
              RubberSegmentItem<Object?>(
                value: o,
                // Visible overflow: the segment can measure the label before
                // the web font has loaded, and would cut it short.
                label: Text(
                  knob.labelFor(o),
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ),
          ],
          value: value,
          height: 38,
          segmentPadding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: p.surface,
          thumbColor: p.ink,
          selectedForegroundColor: p.bg,
          foregroundColor: p.muted,
          borderRadius: kCorners,
          textStyle: text,
          fitContent: true,
          enableHaptics: false,
          onChanged: (v) => knobs.set(knob.id, v),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: GlideSelect<Object?>(
        options: [
          for (final Object? o in options)
            GlideSelectOption<Object?>(value: o, label: knob.labelFor(o)),
        ],
        value: value,
        borderRadius: kCorners,
        chipColor: p.surface,
        chipBorderColor: p.surface,
        menuColor: p.bg,
        highlightColor: p.surface,
        checkColor: p.ink,
        textStyle: text,
        semanticLabel: knob.label,
        onChanged: (v) => knobs.set(knob.id, v),
      ),
    );
  }
}

class _ColorControl extends StatelessWidget {
  const _ColorControl({
    required this.knob,
    required this.knobs,
    required this.value,
  });

  final ColorKnob knob;
  final Knobs knobs;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final Color? swatch in knob.swatches)
          Semantics(
            button: true,
            selected: swatch == value,
            label: swatch == null ? 'Default color' : colorCode(swatch),
            child: TapFeedback(
              enableHaptics: false,
              onTap: () => knobs.set(knob.id, swatch),
              child: AnimatedContainer(
                duration: Motion.fast,
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: swatch == value ? p.ink : p.bg.withValues(alpha: 0),
                  borderRadius: kCorners,
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: swatch ?? p.surface,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                  child: swatch == null
                      ? Text(
                          'A',
                          style: AppFonts.text(
                            TextStyle(fontSize: 13, color: p.muted),
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TextControl extends StatefulWidget {
  const _TextControl({required this.knob, required this.knobs});

  final TextKnob knob;
  final Knobs knobs;

  @override
  State<_TextControl> createState() => _TextControlState();
}

class _TextControlState extends State<_TextControl> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.knobs.text(widget.knob.id),
  );

  @override
  void initState() {
    super.initState();
    widget.knobs.addListener(_sync);
  }

  void _sync() {
    final String v = widget.knobs.text(widget.knob.id);
    if (v != _controller.text) _controller.text = v;
  }

  @override
  void dispose() {
    widget.knobs.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: AppType.body(context).copyWith(fontSize: 16),
      onChanged: (v) =>
          widget.knobs.set(widget.knob.id, v.isEmpty ? widget.knob.initial : v),
    );
  }
}
