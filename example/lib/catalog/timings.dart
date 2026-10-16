/// The default timing of each component, as shown in the component tables:
/// the main duration from the widget's constructor defaults. "Loop" marks
/// effects that run continuously with no single duration.
const Map<String, String> defaultTimings = {
  // AI & Agents
  'border-beam': 'Loop',
  'thinking-steps': '300 ms',
  'tool-call-chip': '520 ms',
  'thinking-orb': '250 ms',
  'streaming-text': '400 ms',
  'voice-glow': 'Live',
  'voice-pill': 'Live',
  'voice-waveform': 'Live',
  'refine-frame': '700 ms',
  'shimmer-text': '1.6 s',
  'typing-indicator': '1.2 s',
  'status-mark': '350 ms',
  // Text
  'text-reveal': '450 ms',
  'decrypted-text': '50 ms a tick',
  'rotating-text': '500 ms',
  'gradient-text': '3 s',
  'typewriter-text': '60 ms a letter',
  // Borders & Glow
  'comet-border': '4 s',
  'electric-border': 'Loop',
  'animated-gradient-border': '3 s',
  'hover-glow': '200 ms',
  // Pointer & Hover
  'magnet': '300 ms',
  'spotlight-card': '250 ms',
  'tilt-card': '150 ms',
  'glare-hover': '650 ms',
  'click-spark': '400 ms',
  // Backgrounds & Overlays
  'gradual-blur': 'Static',
  'grain-overlay': '12 fps',
  'expandable-fab': '300 ms',
  'long-press-menu': '200 ms',
  'warm-tooltip': '240 ms',
  'branched-menu': '300 ms',
  // Cards & Carousels
  'depth-carousel': '3 s a slide',
  'reflective-card': '6 s idle',
  'orbit-items': '12 s a turn',
  'logo-loop': '60 px a second',
  'card-flip': '500 ms',
  // Buttons & Inputs
  'tap-feedback': '150 ms',
  'button-states': '300 ms',
  'shimmer-button': '120 ms',
  'ripple': '800 ms',
  'shake': '400 ms',
  'slide-to-confirm': '300 ms',
  'hold-to-confirm': '1.5 s',
  'input-focus': '200 ms',
  'floating-label': '200 ms',
  'code-slots': '200 ms',
  'pulse-heart': '700 ms',
  'fuse-button': '320 ms',
  'sling-button': '750 ms',
  'bell-toggle': '420 ms',
  // Controls
  'squish-switch': 'Spring',
  'rubber-segment': 'Spring',
  'jelly-radio': 'Spring',
  'spring-checkbox': 'Spring',
  'wake-slider': 'Spring',
  'comet-dial': 'Spring',
  'glide-select': '260 ms',
  'scrub-field': '150 ms',
  'peek-rating': '560 ms',
  // Feedback
  'toast': '250 ms',
  'success-burst': '700 ms',
  'animated-check': '700 ms',
  'animated-counter': '500 ms',
  'animated-badge': '300 ms',
  'pulse-highlight': '1.5 s',
  // Lists & Scroll
  'staggered-list': '400 ms',
  'reveal-on-scroll': '600 ms',
  'swipe-actions': '250 ms',
  'reorderable-list': '200 ms',
  'pull-to-refresh': 'Gesture',
  'elastic-scroll': 'Spring',
  'parallax': 'Scroll',
  // Loading & Progress
  'skeletons': '1.5 s',
  'lattice-loader': 'Loop',
  'liquid-progress': '600 ms',
  // Transitions
  'page-route': '300 ms',
  'pixel-transition': '600 ms',
  'pixel-swap': '700 ms',
  'halftone-reveal': '500 ms',
  'morphing-shapes': '800 ms',
};

/// The default timing of the entry with [id], or an empty string.
String timingOf(String id) => defaultTimings[id] ?? '';
