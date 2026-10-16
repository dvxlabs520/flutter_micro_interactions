import 'dart:math' as math;

import 'categories.dart';
import 'models.dart';

import '../demos/ai/border_beam.dart';
import '../demos/ai/refine_frame.dart';
import '../demos/ai/shimmer_text.dart';
import '../demos/ai/status_mark.dart';
import '../demos/ai/streaming_text.dart';
import '../demos/ai/thinking_orb.dart';
import '../demos/ai/thinking_steps.dart';
import '../demos/ai/tool_call_chip.dart';
import '../demos/ai/typing_indicator.dart';
import '../demos/ai/voice_glow.dart';
import '../demos/ai/voice_pill.dart';
import '../demos/ai/voice_waveform.dart';
import '../demos/backgrounds/branched_menu.dart';
import '../demos/backgrounds/expandable_fab.dart';
import '../demos/backgrounds/gradual_blur.dart';
import '../demos/backgrounds/grain_overlay.dart';
import '../demos/backgrounds/long_press_menu.dart';
import '../demos/backgrounds/warm_tooltip.dart';
import '../demos/borders/animated_gradient_border.dart';
import '../demos/borders/comet_border.dart';
import '../demos/borders/electric_border.dart';
import '../demos/borders/hover_glow.dart';
import '../demos/buttons/bell_toggle.dart';
import '../demos/buttons/button_states.dart';
import '../demos/buttons/code_slots.dart';
import '../demos/buttons/floating_label.dart';
import '../demos/buttons/fuse_button.dart';
import '../demos/buttons/hold_to_confirm.dart';
import '../demos/buttons/input_focus.dart';
import '../demos/buttons/pulse_heart.dart';
import '../demos/buttons/ripple.dart';
import '../demos/buttons/shake.dart';
import '../demos/buttons/shimmer_button.dart';
import '../demos/buttons/slide_to_confirm.dart';
import '../demos/buttons/sling_button.dart';
import '../demos/buttons/tap_feedback.dart';
import '../demos/cards/card_flip.dart';
import '../demos/cards/depth_carousel.dart';
import '../demos/cards/logo_loop.dart';
import '../demos/cards/morph_slider.dart';
import '../demos/cards/orbit_items.dart';
import '../demos/cards/reflective_card.dart';
import '../demos/controls/comet_dial.dart';
import '../demos/controls/glide_select.dart';
import '../demos/controls/jelly_radio.dart';
import '../demos/controls/peek_rating.dart';
import '../demos/controls/rubber_segment.dart';
import '../demos/controls/scrub_field.dart';
import '../demos/controls/spring_checkbox.dart';
import '../demos/controls/squish_switch.dart';
import '../demos/controls/wake_slider.dart';
import '../demos/feedback/animated_badge.dart';
import '../demos/feedback/animated_check.dart';
import '../demos/feedback/animated_counter.dart';
import '../demos/feedback/pulse_highlight.dart';
import '../demos/feedback/success_burst.dart';
import '../demos/feedback/toast.dart';
import '../demos/lists/elastic_scroll.dart';
import '../demos/lists/parallax.dart';
import '../demos/lists/pull_to_refresh.dart';
import '../demos/lists/reorderable_list.dart';
import '../demos/lists/reveal_on_scroll.dart';
import '../demos/lists/staggered_list.dart';
import '../demos/lists/swipe_actions.dart';
import '../demos/loading/lattice_loader.dart';
import '../demos/loading/liquid_progress.dart';
import '../demos/loading/skeletons.dart';
import '../demos/pointer/click_spark.dart';
import '../demos/pointer/glare_hover.dart';
import '../demos/pointer/magnet.dart';
import '../demos/pointer/spotlight_card.dart';
import '../demos/pointer/tilt_card.dart';
import '../demos/text/decrypted_text.dart';
import '../demos/text/gradient_text.dart';
import '../demos/text/rotating_text.dart';
import '../demos/text/text_reveal.dart';
import '../demos/text/typewriter_text.dart';
import '../demos/transitions/halftone_reveal.dart';
import '../demos/transitions/morphing_shapes.dart';
import '../demos/transitions/page_route.dart';
import '../demos/transitions/pixel_swap.dart';
import '../demos/transitions/pixel_transition.dart';

export 'categories.dart';
export 'models.dart';

/// Every component of the gallery. The order inside a category is the
/// order in the sidebar and on the home page.
///
/// To add a component: create `lib/demos/<category>/<name>.dart` with a
/// `final ComponentEntry fooEntry = ComponentEntry(...)`, import it above
/// and add `fooEntry` below.
final List<ComponentEntry> registry = [
  // AI & Agents
  borderBeamEntry,
  thinkingStepsEntry,
  toolCallChipEntry,
  thinkingOrbEntry,
  streamingTextEntry,
  voiceGlowEntry,
  voicePillEntry,
  voiceWaveformEntry,
  refineFrameEntry,
  shimmerTextEntry,
  typingIndicatorEntry,
  statusMarkEntry,
  // Text
  textRevealEntry,
  decryptedTextEntry,
  rotatingTextEntry,
  gradientTextEntry,
  typewriterTextEntry,
  // Borders & Glow
  cometBorderEntry,
  electricBorderEntry,
  animatedGradientBorderEntry,
  hoverGlowEntry,
  // Pointer & Hover
  magnetEntry,
  spotlightCardEntry,
  tiltCardEntry,
  glareHoverEntry,
  clickSparkEntry,
  // Backgrounds & Overlays
  gradualBlurEntry,
  grainOverlayEntry,
  expandableFabEntry,
  longPressMenuEntry,
  branchedMenuEntry,
  warmTooltipEntry,
  // Cards & Carousels
  depthCarouselEntry,
  morphSliderEntry,
  reflectiveCardEntry,
  orbitItemsEntry,
  logoLoopEntry,
  cardFlipEntry,
  // Buttons & Inputs
  tapFeedbackEntry,
  buttonStatesEntry,
  shimmerButtonEntry,
  pulseHeartEntry,
  bellToggleEntry,
  fuseButtonEntry,
  slingButtonEntry,
  rippleEntry,
  shakeEntry,
  slideToConfirmEntry,
  holdToConfirmEntry,
  inputFocusEntry,
  floatingLabelEntry,
  codeSlotsEntry,
  // Controls
  squishSwitchEntry,
  rubberSegmentEntry,
  jellyRadioEntry,
  springCheckboxEntry,
  wakeSliderEntry,
  cometDialEntry,
  glideSelectEntry,
  scrubFieldEntry,
  peekRatingEntry,
  // Feedback
  toastEntry,
  successBurstEntry,
  animatedCheckEntry,
  animatedCounterEntry,
  animatedBadgeEntry,
  pulseHighlightEntry,
  // Lists & Scroll
  staggeredListEntry,
  revealOnScrollEntry,
  swipeActionsEntry,
  reorderableListEntry,
  pullToRefreshEntry,
  elasticScrollEntry,
  parallaxEntry,
  // Loading & Progress
  skeletonsEntry,
  latticeLoaderEntry,
  liquidProgressEntry,
  // Transitions
  pageRouteEntry,
  pixelTransitionEntry,
  pixelSwapEntry,
  halftoneRevealEntry,
  morphingShapesEntry,
];

/// Lookup helpers over [registry].
abstract final class Catalog {
  /// Entries grouped by category, in category order.
  static List<ComponentEntry> get ordered => [
    for (final Category c in Categories.components) ...entriesIn(c),
  ];

  static List<ComponentEntry> entriesIn(Category category) =>
      registry.where((e) => e.category == category).toList();

  static ComponentEntry? byId(String id) {
    for (final ComponentEntry e in registry) {
      if (e.id == id) return e;
    }
    return null;
  }

  static ComponentEntry? previous(ComponentEntry entry) {
    final List<ComponentEntry> all = ordered;
    final int i = all.indexOf(entry);
    return i > 0 ? all[i - 1] : null;
  }

  static ComponentEntry? next(ComponentEntry entry) {
    final List<ComponentEntry> all = ordered;
    final int i = all.indexOf(entry);
    return i >= 0 && i < all.length - 1 ? all[i + 1] : null;
  }

  static const Set<String> _stopWords = {
    'a',
    'an',
    'and',
    'for',
    'the',
    'of',
    'to',
    'in',
    'on',
    'with',
    'is',
    'that',
    'my',
    'some',
    'when',
    'while',
  };

  /// Words people type for the same thing.
  static const Map<String, List<String>> _synonyms = {
    'toggle': ['switch'],
    'switch': ['toggle'],
    'spring': ['squish', 'jelly', 'rubber'],
    'load': ['loader', 'skeleton', 'progress', 'thinking'],
    'spinner': ['loader', 'thinking', 'orb'],
    'ai': ['agent', 'thinking', 'stream'],
    'agent': ['ai'],
    'glow': ['beam', 'border'],
    'pay': ['confirm', 'checkout'],
    'payment': ['confirm', 'checkout'],
    'star': ['rating'],
    'rating': ['star'],
    'notification': ['toast', 'badge', 'bell'],
    'menu': ['branched', 'fab'],
    'carousel': ['slider', 'depth'],
    'image': ['halftone', 'pixel', 'morph'],
    'text': ['type', 'reveal'],
  };

  /// Reduces a word to a rough stem, so "springy" finds "spring" and
  /// "loading" finds "load".
  static String _stem(String w) {
    for (final String suffix in ['ing', 'ies', 'es', 'y', 's', 'ed']) {
      if (w.length - suffix.length >= 4 && w.endsWith(suffix)) {
        return w.substring(0, w.length - suffix.length);
      }
    }
    return w;
  }

  /// Entries ranked by how well they match [query]. Every word counts:
  /// a hit in the name weighs most, then the class names, then the
  /// summary and category. Entries matching no word are left out.
  static List<ComponentEntry> search(String query) {
    final List<String> words = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.isNotEmpty && !_stopWords.contains(w))
        .map(_stem)
        .toList();
    if (words.isEmpty) return const [];
    final List<(ComponentEntry, int)> scored = [];
    for (final ComponentEntry e in ordered) {
      final String name = e.name.toLowerCase();
      final String apis = e.apis.join(' ').toLowerCase();
      final String rest = e.searchText;
      int score = 0;
      for (final String w in words) {
        int best = 0;
        for (final String v in [w, ...?_synonyms[w]]) {
          // A synonym counts a little less than the word itself.
          final int bonus = v == w ? 0 : -1;
          if (name.contains(v)) {
            best = math.max(best, 6 + bonus);
          } else if (apis.contains(v)) {
            best = math.max(best, 4 + bonus);
          } else if (rest.contains(v)) {
            best = math.max(best, 2 + bonus);
          }
        }
        score += best;
      }
      if (score > 0) scored.add((e, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (ComponentEntry e, int _) in scored) e];
  }

  static int get count => registry.length;

  static int get newCount => registry.where((e) => e.isNew).length;
}
