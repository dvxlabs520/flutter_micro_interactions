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
