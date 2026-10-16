import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../app.dart';
import '../catalog/registry.dart';
import '../shared/code_view.dart';
import '../shared/component_table.dart';
import '../shared/generated_images.dart';
import '../shared/links.dart';
import '../shared/preview_card.dart';
import '../shared/ui.dart';
import '../shell/shell.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The overview, a single scrolling page made of sentences with evidence:
/// a sentence split by a reel of live widgets, a headline you can type,
/// the life of a tap as one bar, the index, four promises with live proof,
/// a figure set by a slider and an invitation over the cropped name.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.showBar = true});

  /// Wide screens scroll the site bar away with the page.
  final bool showBar;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset: _takeInitialOffset(),
  );

  static double _takeInitialOffset() {
    final double y = initialScrollOffset ?? 0;
    initialScrollOffset = null;
    return y;
  }

  @override
  void initState() {
    super.initState();
    // A requested offset past the end means "the bottom": the lazy slivers
    // only know the full extent after a few frames.
    if (_scroll.initialScrollOffset > 0) _settle(20);
  }

  void _settle(int tries) {
    // Retried on a timer: the extent grows as slivers are laid out.
    Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_scroll.hasClients || tries == 0) return;
      final ScrollPosition pos = _scroll.position;
      final double target = math.min(
        _scroll.initialScrollOffset,
        pos.maxScrollExtent,
      );
      if ((pos.pixels - target).abs() > 1) pos.jumpTo(target);
      _settle(tries - 1);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double margin = pageMargin(w);
        final bool phone = w < Breakpoints.phone;
        final double gap = phone ? 112 : 176;
        Widget box(Widget child) => SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            child: child,
          ),
        );
        return Scrollbar(
          controller: _scroll,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              // Below 1000 px the sentence halves stack around the frame.
              _HeroReel(
                margin: margin,
                phone: w < 1000,
                showBar: widget.showBar,
              ),
              SliverToBoxAdapter(child: SizedBox(height: gap * 0.6)),
              box(_TypeToSearch(phone: phone)),
              SliverToBoxAdapter(child: SizedBox(height: gap)),
              box(_LifeOfATap(phone: phone)),
              SliverToBoxAdapter(child: SizedBox(height: gap)),
              box(const _IndexSection()),
              SliverToBoxAdapter(child: SizedBox(height: gap)),
              box(_Promises(phone: phone)),
              SliverToBoxAdapter(child: SizedBox(height: gap)),
              box(_FrameCounter(phone: phone)),
              SliverToBoxAdapter(child: SizedBox(height: gap * 0.6)),
              SliverToBoxAdapter(
                child: _Invitation(margin: margin, phone: phone),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Hero: a sentence split by a frame, the frame a pinned reel of widgets.
// ---------------------------------------------------------------------------

class _HeroReel extends StatelessWidget {
  const _HeroReel({
    required this.margin,
    required this.phone,
    required this.showBar,
  });

  final double margin;
  final bool phone;

  /// Pins the site bar with the poster during the reel, then lets both
  /// scroll away.
  final bool showBar;

  static const int _frames = 4;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final double vh = constraints.viewportMainAxisExtent;
        final double stage = math.max(phone ? 640.0 : 560.0, vh);
        // Each frame holds for about 0.6 of a screen of scrolling.
        final double run = stage * 0.6 * (_frames - 1);
        final double offset = constraints.scrollOffset.clamp(0.0, run);
        final double t = run == 0 ? 0 : offset / run * (_frames - 1);
        return SliverToBoxAdapter(
          child: SizedBox(
            height: stage + run,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: offset,
                  height: stage,
                  child: Column(
                    children: [
                      if (showBar) const SiteBar(route: HomeRoute()),
                      Expanded(
                        child: _HeroPoster(
                          progress: _hold(t),
                          margin: margin,
                          phone: phone,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Holds each frame still for most of its run and moves between frames
  /// with an ease.
  static double _hold(double t) {
    final int i = t.floor().clamp(0, _frames - 1);
    final double f = t - i;
    final double move = ((f - 0.3) / 0.4).clamp(0.0, 1.0);
    return i + Curves.easeInOutCubic.transform(move);
  }
}

class _HeroPoster extends StatelessWidget {
  const _HeroPoster({
    required this.progress,
    required this.margin,
    required this.phone,
  });

  final double progress;
  final double margin;
  final bool phone;

  static const List<Widget> _reel = [
    _ReelAgent(),
    _ReelControls(),
    _ReelOrbs(),
    _ReelHalftone(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final double w = c.maxWidth;
        final double h = c.maxHeight;
        if (phone) return _phoneLayout(context, w, h);
        final double frameW = w * 0.35;
        final double frameH = frameW * 9 / 16;
        final double halfW = (w - frameW) / 2 - margin - 28;
        final TextStyle line = AppType.displayAt(
          context,
          math.min(w * 0.11, 168),
        ).copyWith(height: 0.9);
        return Stack(
          children: [
            Positioned.fill(
              child: _Reel(
                progress: progress,
                left: (w - frameW) / 2,
                frameW: frameW,
                frameH: frameH,
                sliver: 60,
                height: h,
              ),
            ),
            Positioned(
              left: margin,
              width: halfW,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('TINY MOTION,', style: line),
                ),
              ),
            ),
            Positioned(
              right: margin,
              width: halfW,
              top: 0,
              bottom: 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text('ONE WIDGET.', style: line),
                ),
              ),
            ),
            Positioned(
              left: margin,
              bottom: 40,
              width: math.min(440, halfW + 40),
              child: Text(
                'A Flutter package of ${Catalog.count} small, accessible '
                'animations. Each one is a single widget and a few lines of '
                'code.',
                style: AppType.body(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _phoneLayout(BuildContext context, double w, double h) {
    final double frameW = w - margin * 2;
    final double frameH = frameW * 3 / 4;
    final TextStyle line = AppType.displayAt(
      context,
      math.min(w * 0.135, 120),
    ).copyWith(height: 0.9);
    final double frameTop = h * 0.5 - frameH / 2 - 24;
    return Stack(
      children: [
        Positioned.fill(
          child: _Reel(
            progress: progress,
            left: margin,
            frameW: frameW,
            frameH: frameH,
            sliver: 28,
            height: h,
            centerY: frameTop + frameH / 2,
          ),
        ),
        Positioned(
          left: margin,
          right: margin,
          bottom: h - frameTop + 16,
          child: Text('TINY MOTION,', style: line),
        ),
        Positioned(
          left: margin,
          right: margin,
          top: frameTop + frameH + 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ONE WIDGET.', style: line, textAlign: TextAlign.right),
              const SizedBox(height: 20),
              Text(
                'A Flutter package of ${Catalog.count} small, accessible '
                'animations. Each one is a single widget.',
                style: AppType.body(context).copyWith(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const AddToPubspecButton(expand: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// The vertical reel: frames stacked with the current one centered, and a
/// sliver of the previous and next at the top and bottom edges.
class _Reel extends StatelessWidget {
  const _Reel({
    required this.progress,
    required this.left,
    required this.frameW,
    required this.frameH,
    required this.sliver,
    required this.height,
    this.centerY,
  });

  final double progress;
  final double left;
  final double frameW;
  final double frameH;
  final double sliver;
  final double height;
  final double? centerY;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final double cy = centerY ?? height / 2;
    final double pitch = math.max(
      frameH + 24,
      cy - frameH / 2 - sliver + frameH,
    );
    return ClipRect(
      child: Stack(
        children: [
          for (int i = 0; i < _HeroPoster._reel.length; i++)
            Positioned(
              left: left,
              width: frameW,
              top: cy - frameH / 2 + (i - progress) * pitch,
              height: frameH,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: kCorners,
                ),
                child: ExcludeSemantics(
                  excluding: (i - progress).abs() > 0.5,
                  child: Padding(
                    padding: EdgeInsets.all(frameH * 0.08),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _HeroPoster._reel[i],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReelAgent extends StatelessWidget {
  const _ReelAgent();

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final TextStyle text = AppFonts.text(
      TextStyle(fontSize: 15, height: 1.4, color: p.ink),
    );
    return BorderBeam(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ThinkingOrb(state: ThinkingOrbState.working, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: ShimmerText('Planning the migration', style: text),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (String label, MicroStatus status) in const [
              ('Read 18 files', MicroStatus.success),
              ('Found 3 breaking changes', MicroStatus.success),
              ('Drafting the plan', MicroStatus.loading),
            ])
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    StatusMark(status: status, size: 14),
                    const SizedBox(width: 10),
                    Text(label, style: text.copyWith(color: p.muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReelControls extends StatefulWidget {
  const _ReelControls();

  @override
  State<_ReelControls> createState() => _ReelControlsState();
}

class _ReelControlsState extends State<_ReelControls> {
  bool _on = true;
  String _range = 'Week';
  double _rating = 4;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final TextStyle text = AppFonts.text(TextStyle(fontSize: 15, color: p.ink));
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text('Notify me when it ships', style: text)),
              SquishSwitch(
                value: _on,
                activeColor: p.ink,
                onChanged: (v) => setState(() => _on = v),
              ),
            ],
          ),
          const SizedBox(height: 18),
          RubberSegment<String>(
            items: [
              for (final String s in const ['Day', 'Week', 'Month'])
                RubberSegmentItem<String>(
                  value: s,
                  label: Text(
                    s,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
            ],
            value: _range,
            backgroundColor: p.bg,
            thumbColor: p.ink,
            selectedForegroundColor: p.bg,
            foregroundColor: p.muted,
            borderRadius: kCorners,
            onChanged: (v) => setState(() => _range = v),
          ),
          const SizedBox(height: 18),
          PeekRating(
            value: _rating,
            activeColor: p.ink,
            onChanged: (v) => setState(() => _rating = v),
          ),
        ],
      ),
    );
  }
}

class _ReelOrbs extends StatelessWidget {
  const _ReelOrbs();

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final ThinkingOrbState s in const [
          ThinkingOrbState.searching,
          ThinkingOrbState.thinking,
          ThinkingOrbState.composing,
        ])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ThinkingOrb(state: s, size: 84, color: p.ink),
                const SizedBox(height: 10),
                Text(
                  s.label,
                  style: AppFonts.text(TextStyle(fontSize: 14, color: p.muted)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReelHalftone extends StatelessWidget {
  const _ReelHalftone();

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return SizedBox(
      width: 420,
      height: 236,
      child: HalftoneReveal(
        image: const GeneratedImage(style: SceneStyle.mountains, seed: 3),
        cellSize: 7,
        dotColor: p.ink,
        backgroundColor: p.surface,
        borderRadius: BorderRadius.circular(6),
        semanticLabel: 'Mountains at dusk, drawn as halftone dots',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. A headline you can type: the catalog search at display size.
// ---------------------------------------------------------------------------

class _TypeToSearch extends StatefulWidget {
  const _TypeToSearch({required this.phone});

  final bool phone;

  @override
  State<_TypeToSearch> createState() => _TypeToSearchState();
}

class _TypeToSearchState extends State<_TypeToSearch> {
  final TextEditingController _text = TextEditingController(
    text: 'springy toggle',
  );

  static const List<String> _examples = [
    'border glow',
    'loading for AI',
    'confirm a payment',
  ];

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final double vw = MediaQuery.sizeOf(context).width / 100;
    final double size = widget.phone ? 11 * vw : (8 * vw).clamp(48.0, 132.0);
    final List<ComponentEntry> hits = Catalog.search(
      _text.text,
    ).take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Reveal(
          child: TextField(
            controller: _text,
            maxLines: 1,
            cursorWidth: size * 0.08,
            cursorColor: p.ink,
            cursorRadius: Radius.zero,
            cursorHeight: size * 0.82,
            style: AppType.displayAt(context, size).copyWith(height: 1.1),
            decoration: const InputDecoration.collapsed(
              hintText: 'Type a few words',
              filled: false,
            ),
          ),
        ),
        SizedBox(height: widget.phone ? 28 : 48),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: hits.isEmpty
                ? Text(
                    _text.text.trim().isEmpty
                        ? 'Type to search ${Catalog.count} components.'
                        : 'Nothing matches that yet. Try one of the '
                              'examples below.',
                    style: AppType.body(context),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final ComponentEntry e in hits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _Hit(entry: e, phone: widget.phone),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 28,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Type the motion you need, or try',
              style: AppType.body(context).copyWith(fontSize: 17),
            ),
            for (final String q in _examples)
              TextLink(
                label: q,
                onTap: () => _text.text = q,
                style: AppType.body(context).copyWith(fontSize: 17),
              ),
          ],
        ),
      ],
    );
  }
}

class _Hit extends StatelessWidget {
  const _Hit({required this.entry, required this.phone});

  final ComponentEntry entry;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Widget preview = Container(
      width: phone ? double.infinity : 260,
      height: 150,
      decoration: BoxDecoration(color: p.surface, borderRadius: kCorners),
      child: KeyedSubtree(
        key: ValueKey(entry.id),
        child: EntryThumbnail(entry: entry),
      ),
    );
    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.name, style: AppType.lead(context)),
        const SizedBox(height: 6),
        Text(
          entry.summary,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppType.body(context).copyWith(fontSize: 16),
        ),
        const SizedBox(height: 6),
        TextLink(
          label: 'Open ${entry.name}',
          onTap: () => openRoute(context, ComponentRoute(entry)),
          style: AppType.small(context),
        ),
      ],
    );
    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [preview, const SizedBox(height: 12), words],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        preview,
        const SizedBox(width: 24),
        Expanded(child: words),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. The life of a tap, as one bar sized by the real default durations.
// ---------------------------------------------------------------------------

class _LifeOfATap extends StatelessWidget {
  const _LifeOfATap({required this.phone});

  final bool phone;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final List<(int, String, String, Color, Color)> stages = [
      (
        150,
        '150 milliseconds',
        'Press. TapFeedback scales the button down to 95 percent.',
        p.ink,
        p.bg,
      ),
      (
        300,
        '300 milliseconds',
        'Answer. ButtonStates swaps the label for a spinner.',
        p.muted,
        p.bg,
      ),
      (
        700,
        '700 milliseconds',
        'Done. AnimatedCheck draws its stroke, start to end.',
        p.surfaceStrong,
        p.ink,
      ),
      (
        250,
        '250 milliseconds',
        'Told. A toast slides in and is read aloud.',
        p.surface,
        p.ink,
      ),
    ];
    final int total = stages.fold(0, (s, e) => s + e.$1);
    final double vh = MediaQuery.sizeOf(context).height / 100;
    final TextStyle inside = AppType.lead(context);

    final Widget heading = Reveal(
      child: Text('THE LIFE\nOF A TAP', style: AppType.head(context)),
    );
    final Widget aside = Reveal(
      order: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(
          'A save button, start to finish: $total milliseconds, four '
          'widgets, each at its default timing. Try it.',
          style: AppType.body(context),
        ),
      ),
    );

    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: 20),
          aside,
          const SizedBox(height: 20),
          const _SaveButtonDemo(),
          const SizedBox(height: 32),
          for (final s in stages)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Reveal(
                child: Container(
                  height: math.max(72, 70 * vh * s.$1 / total),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: s.$4,
                    borderRadius: kCorners,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.$2,
                        style: inside.copyWith(color: s.$5, fontSize: 21),
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          s.$3,
                          overflow: TextOverflow.fade,
                          style: AppType.body(
                            context,
                          ).copyWith(color: s.$5, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: heading),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                aside,
                const SizedBox(height: 20),
                const _SaveButtonDemo(),
              ],
            ),
          ],
        ),
        const SizedBox(height: 56),
        Reveal(
          order: 2,
          child: LayoutBuilder(
            builder: (context, c) {
              const double gap = 6;
              final double usable = c.maxWidth - gap * (stages.length - 1);
              // Each segment follows its true duration, 12 percent minimum.
              final List<double> raw = [
                for (final s in stages) math.max(0.17, s.$1 / total),
              ];
              final double sum = raw.fold(0, (a, b) => a + b);
              final List<double> widths = [
                for (final r in raw) usable * r / sum,
              ];
              return Column(
                children: [
                  SizedBox(
                    height: (22 * vh).clamp(150.0, 230.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < stages.length; i++) ...[
                          if (i > 0) const SizedBox(width: gap),
                          Container(
                            width: widths[i],
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: stages[i].$4,
                              borderRadius: kCorners,
                            ),
                            alignment: Alignment.topLeft,
                            child: Text(
                              stages[i].$2,
                              style: inside.copyWith(color: stages[i].$5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < stages.length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: widths[i],
                          child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              stages[i].$3,
                              style: AppType.body(
                                context,
                              ).copyWith(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The tap from the bar, for real: TapFeedback, ButtonStates, AnimatedCheck
/// and a toast at their default timings.
class _SaveButtonDemo extends StatefulWidget {
  const _SaveButtonDemo();

  @override
  State<_SaveButtonDemo> createState() => _SaveButtonDemoState();
}

class _SaveButtonDemoState extends State<_SaveButtonDemo> {
  final ButtonStateController _controller = ButtonStateController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.state != MicroButtonState.idle) return;
    await _controller.run(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    if (mounted) showSiteToast(context, 'Changes saved');
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return TapFeedback(
      enableHaptics: false,
      onTap: _save,
      child: ButtonStates(
        controller: _controller,
        autoResetDuration: const Duration(milliseconds: 1400),
        loadingBuilder: (context) => SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.bg),
        ),
        successBuilder: (context) => AnimatedCheck(
          size: 22,
          strokeWidth: 2.5,
          color: p.bg,
          circleColor: p.bg.withValues(alpha: 0.3),
          semanticLabel: 'Saved',
        ),
        child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: p.ink,
            foregroundColor: p.bg,
            minimumSize: const Size(160, 48),
          ),
          child: const Text('Save changes'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. The index: a statement, the table pushed right.
// ---------------------------------------------------------------------------

class _IndexSection extends StatefulWidget {
  const _IndexSection();

  @override
  State<_IndexSection> createState() => _IndexSectionState();
}

class _IndexSectionState extends State<_IndexSection> {
  Category _category = Categories.ai;

  @override
  Widget build(BuildContext context) {
    final List<Category> categories = [
      for (final Category c in Categories.components)
        if (Catalog.entriesIn(c).isNotEmpty) c,
    ];
    final bool phone = MediaQuery.sizeOf(context).width < Breakpoints.phone;
    return Reveal(
      child: StatementTable(
        headline: 'EVERY WIDGET,\nONE IMPORT',
        table: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 2,
              children: [
                for (final Category c in categories)
                  TextLink(
                    label: c.name,
                    selected: c == _category,
                    onTap: () => setState(() => _category = c),
                    style: AppType.small(context).copyWith(fontSize: 15),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: Motion.medium,
              child: ComponentTable(
                key: ValueKey(_category.id),
                entries: Catalog.entriesIn(_category),
                stacked: phone,
              ),
            ),
          ],
        ),
        under: Padding(
          padding: const EdgeInsets.only(top: 28, left: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextLink(
              label: 'All ${Catalog.count} components',
              onTap: () => openRoute(context, const IndexRoute()),
              style: AppType.lead(context),
              restColor: Palette.of(context).ink,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Promises, each with a live fragment at the right margin.
// ---------------------------------------------------------------------------

class _Promises extends StatelessWidget {
  const _Promises({required this.phone});

  final bool phone;

  @override
  Widget build(BuildContext context) {
    final List<(String, String, Widget, double, double)> rows = [
      (
        'Respects reduced motion',
        'When the system asks for less motion, every widget shows its final '
            'state at once. Flip the switch to see the same reveal both ways.',
        const _ReducedMotionProof(),
        320,
        3 / 2,
      ),
      (
        'Readable by screen readers',
        'Loaders, marks and toasts announce what they mean, like "Loading" '
            'or "Saved", instead of staying silent shapes.',
        const _SemanticsProof(),
        200,
        1,
      ),
      (
        'Nothing to install but Flutter',
        'The package depends on the Flutter SDK and nothing else, so it adds '
            'no transitive packages to your app.',
        const _PubspecProof(),
        260,
        4 / 5,
      ),
      (
        'Flutter 3.44 and newer',
        'Every release is tested on the latest stable Flutter and the one '
            'before it, on mobile, web and desktop.',
        const _VersionsProof(),
        340,
        16 / 9,
      ),
    ];

    final Widget heading = Reveal(
      child: Text('QUIET BY\nDEFAULT', style: AppType.head(context)),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final double axis = phone ? 0 : c.maxWidth * 0.35;
        final List<Widget> children = [
          Padding(
            padding: EdgeInsets.only(left: axis, bottom: phone ? 48 : 96),
            child: heading,
          ),
        ];
        for (int i = 0; i < rows.length; i++) {
          final (
            String title,
            String text,
            Widget proof,
            double pw,
            double ratio,
          ) = rows[i];
          final Widget words = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.lead(context).copyWith(
                  fontSize: phone ? 24 : 30,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Text(text, style: AppType.body(context)),
              ),
            ],
          );
          final Widget picture = Container(
            width: pw,
            height: pw / ratio,
            decoration: BoxDecoration(
              color: Palette.of(context).surface,
              borderRadius: kCorners,
            ),
            clipBehavior: Clip.antiAlias,
            child: proof,
          );
          if (phone) {
            final double factor = [1.0, 0.7, 0.55, 1.0][i];
            final double fw = c.maxWidth * factor;
            children.add(
              Reveal(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      words,
                      const SizedBox(height: 20),
                      Align(
                        alignment: i == 1
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: SizedBox(
                          width: fw,
                          height: fw / ratio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Palette.of(context).surface,
                              borderRadius: kCorners,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: proof,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 88),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: axis),
                    Expanded(child: Reveal(child: words)),
                    const SizedBox(width: 32),
                    Reveal(order: 1, child: picture),
                  ],
                ),
              ),
            );
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

class _ReducedMotionProof extends StatefulWidget {
  const _ReducedMotionProof();

  @override
  State<_ReducedMotionProof> createState() => _ReducedMotionProofState();
}

class _ReducedMotionProofState extends State<_ReducedMotionProof> {
  bool _reduced = false;
  int _run = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _run++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reduce motion',
                  style: AppFonts.text(TextStyle(fontSize: 15, color: p.ink)),
                ),
              ),
              SquishSwitch(
                value: _reduced,
                size: const Size(44, 26),
                activeColor: p.ink,
                semanticLabel: 'Reduce motion',
                onChanged: (v) => setState(() {
                  _reduced = v;
                  _run++;
                }),
              ),
            ],
          ),
          const Spacer(),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: _reduced),
            child: TextReveal(
              key: ValueKey('$_run$_reduced'),
              text: 'Hello, calm.',
              effect: TextRevealEffect.blur,
              style: AppType.displayAt(context, 52),
            ),
          ),
        ],
      ),
    );
  }
}

class _SemanticsProof extends StatefulWidget {
  const _SemanticsProof();

  @override
  State<_SemanticsProof> createState() => _SemanticsProofState();
}

class _SemanticsProofState extends State<_SemanticsProof> {
  static const List<(MicroStatus, String)> _steps = [
    (MicroStatus.loading, 'Loading'),
    (MicroStatus.success, 'Saved'),
    (MicroStatus.error, 'Failed'),
  ];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final (MicroStatus status, String label) = _steps[_i];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StatusMark(
          status: status,
          size: 56,
          strokeWidth: 3,
          loadingColor: p.ink,
          successColor: p.ink,
          semanticLabel: label,
        ),
        const SizedBox(height: 16),
        Text(
          'Announced: "$label"',
          style: AppFonts.text(TextStyle(fontSize: 14, color: p.muted)),
        ),
      ],
    );
  }
}

class _PubspecProof extends StatelessWidget {
  const _PubspecProof();

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'pubspec of the package',
            style: AppFonts.text(TextStyle(fontSize: 14, color: p.muted)),
          ),
          const SizedBox(height: 14),
          Text(
            'dependencies:\n  flutter:\n    sdk: flutter',
            style: AppFonts.mono(
              TextStyle(fontSize: 14, height: 1.7, color: p.ink),
            ),
          ),
          const Spacer(),
          const Align(
            alignment: Alignment.bottomRight,
            child: LatticeLoader(label: 'Resolving', showTimer: false),
          ),
        ],
      ),
    );
  }
}

class _VersionsProof extends StatelessWidget {
  const _VersionsProof();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolCallChip(
            label: 'Tests on Flutter 3.47',
            status: MicroStatus.success,
            icon: Icons.check,
            elapsed: Duration(seconds: 41),
          ),
          SizedBox(height: 10),
          ToolCallChip(
            label: 'Tests on Flutter 3.44',
            status: MicroStatus.success,
            icon: Icons.check,
            elapsed: Duration(seconds: 39),
          ),
          SizedBox(height: 10),
          ToolCallChip(
            label: 'Build for web',
            status: MicroStatus.loading,
            icon: Icons.language,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. A figure set by a slider: frames at 120 Hz.
// ---------------------------------------------------------------------------

class _FrameCounter extends StatefulWidget {
  const _FrameCounter({required this.phone});

  final bool phone;

  @override
  State<_FrameCounter> createState() => _FrameCounterState();
}

class _FrameCounterState extends State<_FrameCounter> {
  double _ms = 400;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Size screen = MediaQuery.sizeOf(context);
    final int frames = (_ms * 120 / 1000).round();
    final double figure = widget.phone
        ? screen.width * 0.3
        : (screen.width * 0.19).clamp(140.0, 320.0);
    final TextStyle big = AppType.displayAt(
      context,
      figure,
    ).copyWith(height: 0.8, fontFeatures: const [FontFeature.tabularFigures()]);
    final Widget sentence = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Text(
        'At 120 Hz a frame lasts 8.3 ms, so ${_ms.round()} ms is $frames '
        'frames on screen.',
        style: AppType.body(context),
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: screen.height * 0.84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Reveal(
            child: Text(
              'HOW LONG IS YOUR\nANIMATION?',
              style: AppType.head(context),
            ),
          ),
          const SizedBox(height: 28),
          Reveal(
            order: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.phone ? double.infinity : 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Duration',
                            style: AppType.body(context).copyWith(fontSize: 16),
                          ),
                        ),
                        Text(
                          '${_ms.round()} ms',
                          style: AppType.body(
                            context,
                          ).copyWith(fontSize: 16, color: p.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    WakeSlider(
                      value: _ms,
                      min: 50,
                      max: 1500,
                      divisions: 145,
                      height: 44,
                      activeColor: p.ink,
                      inactiveColor: p.surfaceStrong,
                      semanticLabel: 'Animation duration',
                      semanticFormatterCallback: (v) => '${v.round()} ms',
                      onChanged: (v) => setState(() => _ms = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: widget.phone ? 120 : 160),
          if (widget.phone) ...[
            Text('$frames', style: big),
            Text('frames', style: AppType.lead(context)),
            const SizedBox(height: 20),
            sentence,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$frames', style: big),
                      SizedBox(width: figure * 0.06),
                      Text(
                        'FRAMES',
                        style: AppType.displayAt(context, figure * 0.22),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: sentence,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. The invitation over the cropped name.
// ---------------------------------------------------------------------------

class _Invitation extends StatelessWidget {
  const _Invitation({required this.margin, required this.phone});

  final double margin;
  final bool phone;

  /// Left side bearing of Imbue's "M", as a fraction of the font size:
  /// the stem starts this far right of the text origin.
  static const double _bearing = 0.012;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final Color text = p.bg;
    return LayoutBuilder(
      builder: (context, c) {
        final double w = c.maxWidth;
        final double content = w - margin * 2;
        final TextStyle linkStyle = AppFonts.text(
          TextStyle(fontSize: phone ? 15 : 17, height: 1.5, color: text),
        );
        final TextStyle small = AppFonts.text(
          TextStyle(fontSize: 14, height: 1.5, color: text),
        );
        const List<(String, String)> links = [
          ('GitHub', Links.repo),
          ('pub.dev', Links.pubDev),
          ('Changelog', Links.changelog),
          ('License', Links.license),
        ];
        Widget link((String, String) l) => TextLink(
          label: l.$1,
          onTap: () => openLink(context, l.$2),
          style: linkStyle,
          restColor: text,
          padding: const EdgeInsets.symmetric(vertical: 3),
        );

        // The invitation is a display line, as large as the section heads.
        final double inviteSize = phone
            ? w * 0.11
            : (w * 0.085).clamp(72.0, 140.0);
        final TextStyle invite = AppType.displayAt(
          context,
          inviteSize,
        ).copyWith(color: text, height: 0.92);

        final Widget button = SizedBox(
          width: phone ? double.infinity : null,
          child: FilledButton(
            onPressed: () => openLink(context, Links.pubDev),
            child: const Text('Open on pub.dev'),
          ),
        );

        final Widget top;
        if (phone) {
          top = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('MAKE IT\nMOVE.', style: invite),
              const SizedBox(height: 28),
              button,
              const SizedBox(height: 24),
              Wrap(spacing: 20, children: [for (final l in links) link(l)]),
            ],
          );
        } else {
          // The links hang from the same column as the index table above:
          // columns 8 to 12 of the 12 column grid.
          final double tableLeft = 7 * (content + 24) / 12;
          top = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: tableLeft - 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MAKE IT\nMOVE.', style: invite),
                    const SizedBox(height: 32),
                    button,
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Padding(
                  // Top aligned with the cap height of the invitation.
                  padding: EdgeInsets.only(top: inviteSize * 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [for (final l in links) link(l)],
                  ),
                ),
              ),
            ],
          );
        }

        const String credit =
            'Ports of Border Beam, Thinking Orbs and Voice from '
            'libraries.dev (MIT). Inspired by React Bits.';
        final Widget credits = phone
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(credit, style: small),
                  Text('v$packageVersion, MIT License', style: small),
                ],
              )
            : Row(
                children: [
                  Expanded(child: Text(credit, style: small)),
                  Text('v$packageVersion, MIT License', style: small),
                ],
              );

        // The name spans the content width on wide screens and runs off the
        // right edge on phones. It is set at a base size and scaled to the
        // target width, so it stays right when the web font arrives.
        final double nameWidth = content * (phone ? 1.3 : 1.0);
        final TextStyle name = AppType.displayAt(
          context,
          200,
        ).copyWith(color: text, height: 1, letterSpacing: -4);

        return Container(
          color: p.ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  margin,
                  phone ? 64 : 112,
                  margin,
                  0,
                ),
                child: top,
              ),
              SizedBox(height: phone ? 72 : 120),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: credits,
              ),
              SizedBox(height: phone ? 12 : 16),
              // The bottom edge of the field cuts through the letters: only
              // the upper part of the capitals shows.
              ClipRect(
                child: Align(
                  alignment: Alignment.topLeft,
                  heightFactor: 0.56,
                  child: Padding(
                    padding: EdgeInsets.only(left: margin),
                    child: UnconstrainedBox(
                      alignment: Alignment.topLeft,
                      constrainedAxis: Axis.vertical,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: nameWidth,
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          alignment: Alignment.topLeft,
                          child: Transform.translate(
                            // Compensates the left side bearing of the M,
                            // so its stem sits on the page margin.
                            // Lifts it by the empty space above the capitals.
                            offset: const Offset(-_bearing * 200, -0.1 * 200),
                            child: ExcludeSemantics(
                              child: Text(
                                'MICRO',
                                softWrap: false,
                                style: name,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
