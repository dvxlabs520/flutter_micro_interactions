## 0.3.0

The largest release so far: more than 50 new widgets for AI interfaces,
text, borders, pointer effects, carousels, controls and buttons, a redesigned
example app, and improvements to existing widgets. No breaking changes,
except the higher minimum Flutter version.

### Added: AI and agents

* `BorderBeam`: an animated rainbow glow that rides the border of a card,
  button or input, with `beam`, `line` and `pulse` styles, four palettes,
  and a fade in and out driven by `active`. The effect stays on the border;
  `innerGlow` adds an optional soft inner light. A Flutter port of Border
  Beam from libraries.dev.
* `ThinkingOrb`: a dotted 3D orb that replaces a spinner, with nine states
  (working, searching, solving, listening, connecting, weaving, composing,
  thinking, shaping). A Flutter port of Thinking Orbs from libraries.dev.
* `ThinkingSteps`: a reasoning trace with per-step status, a live timer,
  and a smooth collapse when thinking is done.
* `StreamingText`: text that fades or unblurs new words as a response
  streams in, with an optional cursor.
* `VoiceGlow`: a sound reactive glow for voice inputs, with idle, listening,
  processing and off states. A Flutter port of Voice from libraries.dev.
* `VoiceWaveform`: equalizer bars for a recording pill.
* `ShimmerText`: the "Thinking..." light sweep, for text or any widget.
* `TypingIndicator`: typing dots in bounce, pulse and wave styles.
* `ToolCallChip`: an agent tool call chip with a progress wipe, a live timer,
  and a success or error result.
* `LatticeLoader`: a compact loader with a wave of cells and a stopwatch.
* `RefineFrame`: a media frame that steps an image through generation
  stages, with `RefineFrame.blurred` to build the stages from one image.
* `VoicePill`: a mic button that grows into a recording capsule with live
  equalizer bars and a timer.
* `StatusMark`: one glyph that morphs between idle, loading, success and
  error.

### Added: text effects

* `TextReveal`: staggered entrance by character or word with fade, slide,
  blur or scale.
* `DecryptedText`: random glyphs that resolve into the real text, on mount
  or on hover.
* `RotatingText`: cycles phrases letter by letter through a mask.
* `GradientText`: text filled with a sliding or rotating gradient.

### Added: borders and glow

* `CometBorder`: a comet with a tail of light travels the outline.
* `ElectricBorder`: crackling strands of current along the border.

### Added: pointer and hover

* `Magnet`: pulls a widget toward the pointer, then springs back.
* `SpotlightCard`: a card with a spotlight that follows the pointer.
* `TiltCard`: 3D tilt toward the pointer with a glare highlight.
* `GlareHover`: a glossy streak sweeps across on hover or press.
* `ClickSpark`: sparks that burst from every tap.
* `HalftoneReveal`: a halftone image that turns into the real photo under the
  pointer.
* `PixelSwap`: new content builds in cell by cell from where the pointer
  entered.
* `PixelTransition`: a retro pixel dissolve between two widgets.

### Added: cards and carousels

* `DepthCarousel`: cards on a 3D rail with drag, momentum, snapping,
  keyboard and autoplay.
* `MorphSlider`: an image slider that melts, ripples or swirls between
  images with a fragment shader shipped in the package, and a crossfade
  fallback.
* `ReflectiveCard`: a metal card (chrome, gold, graphite or holographic)
  that catches the light as it tilts.
* `LogoLoop`: a seamless infinite marquee.
* `OrbitItems`: items that orbit a center widget along a circle, an ellipse
  or a custom path.

### Added: controls

* `SquishSwitch`, `RubberSegment`, `JellyRadioGroup`, `SpringCheckbox`:
  selection controls with spring physics.
* `PeekRating`: star rating with a wave preview.
* `GlideSelect`: a select chip with a menu that pops from its corner.
* `WakeSlider`, `CometDial`, `ScrubField`: value inputs with physical
  motion.
* `CodeSlots`: a one-time code input with paste and SMS autofill.

### Added: buttons, menus and overlays

* `PulseHeart`, `FuseButton`, `SlingButton`, `BellToggle`: expressive
  buttons.
* `WarmTooltip` and `WarmTooltipGroup`: tooltips that glide between
  neighbours once one is open.
* `BranchedMenu`: collapsible navigation with a traced selection.
* `GradualBlur`: progressive blur toward an edge.
* `GrainOverlay`: animated film grain.
* `RevealOnScroll`: animates a widget in when it scrolls into view.

### Added: confirmation

* `HoldToConfirm`: press and hold to fill a button and confirm, with
  horizontal and liquid fill styles.

Many of the new widgets are inspired by React Bits (reactbits.dev).

### Improved

* `SlideToConfirm`: new `onConfirmAsync`. While its `Future` is pending the
  thumb shows a spinner (`loadingChild`) and the control stays locked;
  errors spring the thumb back and go to the new `onError`.
  `SlideToConfirmController.isLoading` reports the pending state, and
  `loadingSemanticLabel` sets the announcement. `onConfirmed` is now
  optional and behaves exactly as before.
* `ToastNotification`: new `swipeToDismiss` (on by default), `showProgress`
  countdown bar, and `pauseOnHover`.
* `ButtonStateController.run`: shows loading, awaits a task, then shows
  success or error and returns to idle.
* `AnimatedCounter`: new `prefix`, `suffix`, `fractionDigits` and
  `thousandsSeparator` formatting options. The odometer mode now rolls
  digits in and out when the number of digits changes, settles to the new
  width, and clips digits to exactly one line.
* `MicroReorderableList`: new `onReorderItem` callback with indexes already
  adjusted for the removed item. `onReorder` is deprecated.

### Fixed

* `ShapeMorph`: turning `autoReverse` off now stops the loop, and a new
  `duration` applies to a running loop.
* `ParallaxScroll`: the background is painted behind the layers again.
* `ParallaxImage`: the image always covers its area at narrow widths.
* `SkeletonScope` and `LoadingSkeleton`: a new `duration` applies to a
  running shimmer.
* `PulseHighlightController`: listeners are notified when the widget stops
  pulsing on its own (after `maxPulseCount` or a tap).
* `WaterRipple`: paints nothing while stopped instead of static rings.
* `RippleButton`: fills the width it is given.
* `MicroPageRoute`: reuses one curved animation per route and disposes it,
  fixing a memory leak.
* `AnimatedCounter`: see the odometer improvements above.

### Changed

* `AnimatedGradientBorder`: `stop()` now pauses the sweep in place, and
  `start()` resumes from there.
* `RippleEffect` passes its constraints through to its child.
* `HoverGlow` no longer adds a focus stop of its own; it still glows when a
  focusable child has keyboard focus.
* Minimum Flutter version is now 3.44 (Dart 3.12). The package supports the
  latest stable Flutter release and the one before it.
* The repository moved to https://github.com/dvxlabs520/flutter_micro_interactions.

## 0.2.0

New animations, built on the stable 0.1.0 base. No breaking changes.

### Added

* `SuccessBurst`: one-shot particle burst for success confirmations, with
  `SuccessBurstController` and support for repeated bursts.
* `PulseHighlight`: expanding pulse rings that draw attention to a widget,
  with `PulseHighlightController`, auto play, and an optional pulse limit.
* `AnimatedCounter`: animated number changes with two modes, numeric count
  and odometer-style sliding digits.
* `AnimatedBadge`: a count badge attached to a corner of a widget that
  scales in and out and bounces when the count changes.
* `StaggeredList`: staggered entrance animation for list children, with a
  `builder` constructor and a standalone `StaggeredItem` for custom layouts.
* `ShimmerButton`: a call-to-action button with a periodic shimmer sweep,
  keyboard activation, and press feedback.
* `SlideToConfirm`: slide a thumb across a track to confirm an action, with
  a spring return, a confirmed state, and a direct confirm action for screen
  readers and keyboards.
* `ExpandableFab`: a floating action button that expands into a set of
  action buttons, linearly or radially, with staggered entrance.
* `AnimatedCheck`: a checkmark or cross drawn with an animated stroke, for
  loading-to-result flows.
* `AnimatedGradientBorder`: an animated sweeping gradient border around any
  widget.
* `TypewriterText`: text that types itself out, with a blinking cursor,
  deletion, and cycling through several strings.
* `LiquidProgress`: a progress indicator filled with an animated liquid
  wave, in circle or rectangle shape.

All new widgets follow the package conventions: `duration`, `curve`, and
`enabled` parameters, reduced motion support, screen reader support, and
theme-aware default colors.

## 0.1.0

Stabilization release. This version fixes broken behavior, renames classes that
conflicted with the Flutter SDK and popular packages, unifies the API, and adds
accessibility support across the package.

### Breaking changes

* Renamed `ReorderableList` to `MicroReorderableList` (conflicted with the Flutter SDK).
* Removed `TransitionRoute` (conflicted with the Flutter SDK). Use `MicroNavigator` helpers instead.
* Renamed `PageTransition` to `MicroPageRoute` and `PageTransitionType` to `MicroTransitionType`.
* Removed `SharedAxisTransition` and `HeroTransition`.
* Renamed `SwipeAction` to `MicroSwipeAction`.
* Renamed `MenuItem` to `LongPressMenuItem`.
* Renamed `ShapeType` to `MicroShapeType`.
* Renamed `ButtonState` to `MicroButtonState`. `ButtonStates` is now driven by a
  `ButtonStateController` instead of a `GlobalKey`, and state widgets are now
  builders (`loadingBuilder`, `successBuilder`, `errorBuilder`).
* Removed the extensions on `List<Widget>` and `Widget` (`ReorderableListExtension`, `withCardFlip`).
* Removed the unused `onMenuItemSelected` parameter from `LongPressMenu`.
* Minimum Flutter version is now 3.38.

### Fixed

* `MorphingShapes` now morphs between shapes with real path interpolation
  instead of switching halfway through the animation.
* `ElasticScroll` now applies real elastic resistance and an animated snap back.
  `elasticity` and `stiffness` are honored.
* `ParallaxScroll` and `ParallaxImage` now produce a real parallax effect.
* `FloatingLabel` now animates the label on focus, and its `validator` works
  with `Form.validate()`. The error message is no longer shown twice.
* Toast notifications: the close button now dismisses the toast, toasts animate
  out, timers are cancelled correctly, and multiple toasts no longer overlap.
* `ShakeToAction` no longer fires on a simple drag. It now requires a real
  back-and-forth gesture, and can be triggered programmatically with `ShakeController`.
* `HoverGlow` now fades out smoothly when the pointer leaves the widget.
* `SwipeActions` now reveals a row of tappable actions, supports more than one
  action per side, and honors `actionExtentRatio`.
* `MicroReorderableList` no longer crashes when the list of children grows.
* `CardFlip` no longer gets out of sync after rapid taps, and supports both
  controlled and uncontrolled use.
* `TextSkeleton` now renders the shorter last line correctly.
* Widgets now react to configuration changes (`duration`, `curve`, controllers)
  after the first build, and animations are guarded against use after dispose.

### Added

* Reduced motion support across the package. Animations respect the platform
  "reduce motion" setting.
* Screen reader support: semantic buttons, state announcements, custom semantic
  actions for swipe and long press, and live region announcements for toasts.
* Keyboard support for interactive widgets (focus highlight and activation with
  Enter and Space).
* Controllers for programmatic use: `ButtonStateController`, `CardFlipController`,
  `MorphingShapesController`, `ShakeController`, `WaterRippleController`.
* `ToastPosition`, toast styling options, action button, and toast stacking.
* Builder constructors for lists (`ElasticListView.builder`, `MicroReorderableList.builder`).
* `PullToRefresh.adaptive` and full `RefreshIndicator` parameter passthrough.
* Theme-aware default colors, including dark mode support for skeletons.
* Documentation comments for the whole public API.

## 0.0.2

* Added Toast Notifications (animated, multiple styles)
* Added Floating Label Animation (with validation)
* Added Reorderable List Animation (drag & drop, feedback)
* Added Card Flip Animation (3D flip, perspective)

## 0.0.1

* Initial release of flutter_micro_interactions package
* Added ButtonStates widget for interactive button animations
* Added ElasticScroll widget for elastic scrolling effects
* Added HoverGlow widget for hover animations
* Added InputFocus widget for input field animations
* Added LoadingSkeletons widget for loading state animations
* Added LongPressMenu widget for long press interactions
* Added MorphingShapes widget for shape morphing animations
* Added PageTransitions widget for custom page transitions
* Added ParallaxScroll widget for parallax scrolling effects
* Added PullToRefresh widget for pull-to-refresh animations
* Added RippleEffect widget for ripple animations
* Added ShakeToAction widget for shake detection
* Added SwipeActions widget for swipe interactions
* Added TapFeedback widget for tap animations
