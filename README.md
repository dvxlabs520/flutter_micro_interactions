# Flutter Micro Interactions

![AI and agent widgets: BorderBeam, ThinkingOrb, ThinkingSteps, ToolCallChip, StreamingText, VoiceGlow and VoicePill](https://raw.githubusercontent.com/dvxlabs520/flutter_micro_interactions/develop/doc/ai_widgets.gif)

A collection of ready-to-use micro-interactions and animations for Flutter.
Add professional motion to your app with a few lines of code.

Includes a set of clean animations for AI interfaces: a border beam for
agents at work, thinking orbs, a reasoning trace, streaming text, and a
voice glow that reacts to the microphone level.

## Why this package

- Simple API. Wrap a widget, get the animation. Every widget works with sensible defaults.
- Consistent. All widgets share the same core parameters: `duration`, `curve`, and `enabled`.
- Accessible. The package respects the platform "reduce motion" setting, announces state
  changes to screen readers, and supports keyboard focus and activation.
- Safe. Widgets react to configuration changes, clean up their resources, and are guarded
  against use after dispose.
- No extra dependencies. Only Flutter.

## Requirements

Flutter 3.44 or newer. The package is tested on the latest stable release
and the one before it.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_micro_interactions: ^0.3.1
```

Then import it:

```dart
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
```

## Widgets

More than 90 widgets, grouped the same way as in the example app.

### AI and agents

| Widget | What it does |
| --- | --- |
| `BorderBeam` | Rainbow glow that rides the border of a card, button or input |
| `ThinkingOrb` | Dotted 3D orb that replaces a spinner, in nine states |
| `ThinkingSteps` | Reasoning trace with step status, live timer and collapse when done |
| `StreamingText` | Text that fades or unblurs new words as they stream in |
| `ToolCallChip` | Agent tool call chip with a progress wipe, timer and result |
| `LatticeLoader` | Compact loader with a wave of cells and a stopwatch |
| `RefineFrame` | Media frame that steps an image through generation stages |
| `VoiceGlow` | Sound reactive glow for a voice input |
| `VoicePill` | Mic button that grows into a recording capsule with live bars |
| `VoiceWaveform` | Equalizer bars for a recording pill |
| `ShimmerText` | The "Thinking..." light sweep, for text or any widget |
| `TypingIndicator` | Typing dots: bounce, pulse or wave |
| `StatusMark` | One glyph that morphs between idle, loading, success and error |

### Text effects

| Widget | What it does |
| --- | --- |
| `TextReveal` | Staggered entrance by character or word with fade, slide, blur or scale |
| `DecryptedText` | Random glyphs that resolve into the real text |
| `RotatingText` | Cycles phrases letter by letter through a mask |
| `GradientText` | Text filled with a sliding or rotating gradient |
| `TypewriterText` | Text that types itself out, with cursor and looping |

### Borders and glow

| Widget | What it does |
| --- | --- |
| `CometBorder` | A comet with a tail of light travels the outline |
| `ElectricBorder` | Crackling strands of current along the border |
| `AnimatedGradientBorder` | Sweeping gradient border |
| `HoverGlow` | Glow on hover and keyboard focus |

### Pointer and hover

| Widget | What it does |
| --- | --- |
| `Magnet` | Pulls a widget toward the pointer, then springs back |
| `SpotlightCard` | Card with a soft spotlight that follows the pointer |
| `TiltCard` | 3D tilt toward the pointer with a glare highlight |
| `GlareHover` | A glossy streak sweeps across on hover or press |
| `ClickSpark` | Sparks that burst from every tap |
| `HalftoneReveal` | A halftone image that turns into the real photo under the pointer |
| `PixelSwap` | New content builds in cell by cell from where the pointer entered |
| `PixelTransition` | Retro pixel dissolve between two widgets |

### Cards and carousels

| Widget | What it does |
| --- | --- |
| `DepthCarousel` | Cards on a 3D rail with drag, momentum and snapping |
| `MorphSlider` | Image slider that melts, ripples or swirls between images (GPU shader) |
| `ReflectiveCard` | Metal card that catches the light as it tilts |
| `LogoLoop` | Seamless infinite marquee of logos or any widget |
| `OrbitItems` | Items that orbit a center widget along a path |
| `CardFlip` | 3D card flip |

### Controls

| Widget | What it does |
| --- | --- |
| `SquishSwitch` | Switch whose thumb stretches with speed and squashes at the end |
| `RubberSegment` | Segmented control with a thumb that stretches like rubber |
| `JellyRadioGroup` | Radio chips that swell and push their neighbours |
| `SpringCheckbox` | Checkbox that fills, ticks and strikes through its label |
| `PeekRating` | Star rating with a wave preview and a pop on commit |
| `GlideSelect` | Select chip with a menu that pops from its corner |
| `WakeSlider` | Slider made of bars that leaves a wake when dragged fast |
| `CometDial` | Circular dial you turn by angle, with a comet streak |
| `ScrubField` | Number field you drag to scrub, or tap to type |
| `CodeSlots` | One-time code input with paste and SMS autofill |

### Buttons

| Widget | What it does |
| --- | --- |
| `PulseHeart` | Like button that pulses and rolls its count |
| `FuseButton` | Action button with an undo window shown as a burning fuse |
| `SlingButton` | Send button you pull back like a slingshot |
| `BellToggle` | Notification toggle that rings its bell |
| `HoldToConfirm` | Press and hold to fill a button and confirm |
| `SlideToConfirm` | Slide a thumb across a track to confirm, with async support |
| `ShimmerButton` | Call-to-action button with a shimmer sweep |
| `ButtonStates` | Loading, success and error states for any button |
| `TapFeedback` | Scale, bounce or fade feedback on tap |
| `RippleEffect`, `RippleButton`, `WaterRipple` | Ripple animations |
| `ShakeToAction`, `ShakeAnimation`, `ShakeButton` | Shake animations and gestures |

### Menus, overlays and backgrounds

| Widget | What it does |
| --- | --- |
| `WarmTooltip`, `WarmTooltipGroup` | Tooltips that glide between neighbours once one is open |
| `BranchedMenu` | Collapsible navigation with branches and a traced selection |
| `GradualBlur` | Progressive blur toward an edge of scrolling content |
| `GrainOverlay` | Animated film grain over any widget |
| `RevealOnScroll` | Animates a widget in when it scrolls into view |
| `ExpandableFab` | Floating button that expands into a set of actions |
| `LongPressMenu` | Context menu on long press |
| `ToastNotification` | Toasts with swipe to dismiss and a countdown bar |

### Lists, feedback and loading

| Widget | What it does |
| --- | --- |
| `InputFocus` | Lift and scale effect when an input gains focus |
| `FloatingLabel` | Text field with an animated floating label and validation |
| `PullToRefresh` | Pull-to-refresh with Material or adaptive indicator |
| `SwipeActions` | Swipe a list item to reveal tappable actions |
| `MicroReorderableList` | Drag and drop reordering with a lift effect |
| `ParallaxScroll`, `ParallaxImage` | Parallax scrolling effects |
| `ElasticScroll`, `ElasticListView`, `ElasticGridView` | Elastic overscroll |
| `MorphingShapes`, `ShapeMorph` | Smooth morphing between shapes |
| `MicroPageRoute`, `MicroNavigator` | Page transitions (fade, slide, scale, flip, blur, and more) |
| `LoadingSkeleton`, `TextSkeleton`, `CardSkeleton`, `ListItemSkeleton`, `GridItemSkeleton`, `SkeletonLoader` | Loading skeletons with shimmer |
| `SuccessBurst` | Particle burst for success confirmations |
| `PulseHighlight` | Pulse rings that draw attention to a widget |
| `AnimatedCounter` | Animated number changes, with an odometer mode |
| `AnimatedBadge` | Count badge that bounces when the count changes |
| `StaggeredList`, `StaggeredItem` | Staggered entrance animation for lists |
| `AnimatedCheck` | Checkmark or cross drawn with an animated stroke |
| `LiquidProgress` | Progress indicator filled with an animated wave |

## Usage

### AI and agents

#### Border beam

Wrap any card, button or input. Toggle `active` to fade the beam in when an
agent starts working and out when it finishes:

```dart
BorderBeam(
  active: isWorking,
  child: Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Agent'))),
);

// A glow traveling along the bottom edge of a search bar
BorderBeam(style: BorderBeamStyle.line, child: searchField);
```

Styles: `beam` (rotating arc, the default), `line` (bottom edge) and `pulse`
(breathing colors along the whole border). Palettes: `colorful`, `ocean`,
`sunset` and `mono`, or your own `colors`. The effect stays on the border;
set `innerGlow: true` to add a soft light that fades inward from the edge.

#### Thinking orb

A small dotted orb that replaces a spinner. Pick the state that matches
the work:

```dart
ThinkingOrb(state: ThinkingOrbState.searching);

// Inline next to a label
Row(children: [
  ThinkingOrb(state: ThinkingOrbState.thinking, size: 20),
  Text('Thinking...'),
]);
```

States: `working`, `searching`, `solving`, `listening`, `connecting`,
`weaving`, `composing`, `thinking` and `shaping`. Changing the state
crossfades between orbs.

#### Thinking steps

A reasoning trace for agents. The header shows a live timer while
`isThinking` is true, then reads "Thought for 12s" and collapses:

```dart
ThinkingSteps(
  isThinking: !done,
  steps: [
    ThinkingStep(title: 'Reading the question', status: MicroStatus.success),
    ThinkingStep(title: 'Searching the docs', detail: '3 sources', status: MicroStatus.loading),
    ThinkingStep(title: 'Writing the answer'),
  ],
);
```

#### Streaming text

Pass the text received so far and rebuild as tokens arrive. Only the new
words animate:

```dart
StreamingText(
  text: response,
  isStreaming: !done,
  showCursor: true,
  effect: StreamingTextEffect.blur,
);
```

#### Voice glow and waveform

Both take a `level` from 0 to 1 that you compute from your own audio
stack, either as a value or as a `ValueListenable<double>` to avoid
rebuilding the parent on every sample:

```dart
VoiceGlow(
  levelListenable: micLevel,
  state: VoiceGlowState.listening, // idle, listening, processing, off
  child: chatInput,
);

VoiceWaveform(levelListenable: micLevel);
```

#### Shimmer text, typing indicator and status mark

```dart
ShimmerText('Thinking...');
ShimmerText.child(child: Icon(Icons.auto_awesome));

TypingIndicator(style: TypingIndicatorStyle.wave);

StatusMark(status: MicroStatus.loading); // idle, loading, success, error
```

#### Tool calls, loaders and image generation

```dart
ToolCallChip(label: 'Searching the web', icon: Icons.public, status: MicroStatus.loading);

const LatticeLoader(label: 'Generating');

RefineFrame.blurred(image: generatedImage, stage: step, steps: 4);

VoicePill(recording: recording, onChanged: (v) => setState(() => recording = v), levelListenable: micLevel);
```

### Text effects

```dart
TextReveal(
  text: 'Make every interaction feel alive',
  splitBy: TextRevealSplit.words,
  effect: TextRevealEffect.blur,
);

DecryptedText(text: 'Access granted', sequential: true);

RotatingText(texts: ['faster', 'smoother', 'together']);

GradientText('Gradient headline', style: TextStyle(fontSize: 32));
```

### Pointer and hover

These follow the mouse, or the finger while it is down, and never block the
taps of the widgets inside:

```dart
Magnet(child: FilledButton(onPressed: buy, child: Text('Buy')));

SpotlightCard(child: Text('Move the pointer here'));

TiltCard(child: Image.asset('card.png'));

ClickSpark(child: FilledButton(onPressed: like, child: Text('Like')));
```

```dart
GlareHover(child: productCard);

HalftoneReveal(image: AssetImage('assets/photo.jpg'));

PixelSwap(first: coverArt, second: trackList);

PixelTransition(firstChild: front, secondChild: back);
```

### Borders and glow

```dart
CometBorder(child: card);
ElectricBorder(color: const Color(0xFF5BC0FF), child: card);
```

Like `BorderBeam`, both stay on the border of the child. Pass a
`borderRadius` that matches the child's shape.

### Cards and carousels

```dart
DepthCarousel(loop: true, children: cards);

MorphSlider(
  images: [AssetImage('a.jpg'), AssetImage('b.jpg')],
  effect: MorphEffect.melt, // melt, ripple or swirl
);

ReflectiveCard(finish: ReflectiveCardFinish.holographic, child: badge);

LogoLoop(children: logos);

OrbitItems(center: logo, children: avatars);
```

`MorphSlider` uses a fragment shader shipped with the package. Call
`MorphSlider.precacheShader()` early so the first transition already uses it;
when shaders are not available it falls back to a crossfade.

### Controls

All controls are controlled widgets: pass the value and update it in
`onChanged`. They support keyboard focus and screen readers like their
Material counterparts.

```dart
SquishSwitch(value: on, onChanged: (v) => setState(() => on = v));

RubberSegment<String>(
  value: range,
  onChanged: (v) => setState(() => range = v),
  items: const [
    RubberSegmentItem(value: 'day', label: Text('Day')),
    RubberSegmentItem(value: 'week', label: Text('Week')),
  ],
);

SpringCheckbox(value: done, onChanged: (v) => setState(() => done = v!), label: Text('Water the plants'));

PeekRating(value: rating, onChanged: (v) => setState(() => rating = v));

WakeSlider(value: volume, onChanged: (v) => setState(() => volume = v));

CodeSlots(length: 6, onCompleted: verify);
```

### Buttons

```dart
PulseHeart(liked: liked, count: likes, onChanged: toggleLike);

FuseButton(
  onPressed: hideItem,
  onUndo: showItem,
  onCommit: deleteItem,
  doneChild: const Text('Deleted'),
  child: const Text('Delete'),
);

SlingButton(onFired: send, child: const Icon(Icons.send_rounded));

BellToggle(value: subscribed, onChanged: (v) => setState(() => subscribed = v));
```

### Menus, overlays and backgrounds

```dart
WarmTooltipGroup(
  child: Row(children: [
    WarmTooltip(message: 'Bold', child: boldButton),
    WarmTooltip(message: 'Italic', child: italicButton),
  ]),
);

GradualBlur(edge: GradualBlurEdge.bottom, child: feed);

GrainOverlay(child: hero);

RevealOnScroll(effect: RevealEffect.slideUp, child: section);
```

### Tap feedback

```dart
TapFeedback.scale(
  onTap: () => print('Tapped'),
  child: const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Tap me'))),
);

// Other effects
TapFeedback.bounce(child: myWidget);
TapFeedback.fade(child: myWidget);
TapFeedback.scaleAndOpacity(child: myWidget);
```

### Button states

Control the state with a `ButtonStateController`:

```dart
final controller = ButtonStateController();

ButtonStates(
  controller: controller,
  child: ElevatedButton(
    onPressed: () async {
      controller.setLoading();
      await submitForm();
      controller.setSuccess();
    },
    child: const Text('Submit'),
  ),
);
```

Or let the controller run the whole flow. `run` shows loading, awaits the
task, then shows success or error and returns to idle:

```dart
await controller.run(() => submitForm());
```

You can pass your own `loadingBuilder`, `successBuilder`, and `errorBuilder`,
and use `autoResetDuration` to return to the idle state automatically.
Remember to dispose the controller.

### Hover glow

```dart
HoverGlow(
  child: Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Hover me'))),
);
```

The glow also appears on keyboard focus.

### Input focus

```dart
InputFocus(
  child: TextField(
    decoration: InputDecoration(labelText: 'Username'),
  ),
);
```

### Floating label

A text field with an animated label that works with `Form` validation:

```dart
FloatingLabel(
  label: 'Email',
  validator: (value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Enter a valid email';
    return null;
  },
);
```

### Pull to refresh

```dart
PullToRefresh(
  onRefresh: () async => loadData(),
  child: ListView(children: items),
);

// Cupertino-style indicator on Apple platforms
PullToRefresh.adaptive(onRefresh: loadData, child: list);
```

### Swipe actions

Swipe to reveal a row of tappable actions. More than one action per side is supported:

```dart
SwipeActions(
  leftActions: [
    MicroSwipeAction.favorite(context, onPressed: markFavorite),
  ],
  rightActions: [
    MicroSwipeAction.archive(context, onPressed: archive),
    MicroSwipeAction.delete(context, onPressed: delete),
  ],
  child: ListTile(title: Text('Swipe me')),
);
```

### Reorderable list

Every child needs a key. `onReorderItem` receives indexes that are already
adjusted for the removed item:

```dart
MicroReorderableList(
  onReorderItem: (oldIndex, newIndex) {
    setState(() => items.insert(newIndex, items.removeAt(oldIndex)));
  },
  children: [
    for (final item in items)
      ListTile(key: ValueKey(item), title: Text(item)),
  ],
);
```

### Long press menu

```dart
LongPressMenu(
  menuItems: [
    LongPressMenuItem.copy(onTap: copy),
    LongPressMenuItem.share(onTap: share),
    LongPressMenuItem.delete(onTap: delete), // styled as destructive
  ],
  child: Card(child: Text('Long press me')),
);
```

### Parallax scroll

```dart
ParallaxScroll(
  background: Image.asset('assets/background.jpg', fit: BoxFit.cover),
  parallaxFactor: 0.5,
  children: [
    // Your scrollable content
  ],
);
```

Use `ParallaxImage` inside any list to give a single image a parallax effect:

```dart
ListView(
  children: [
    ParallaxImage(imageProvider: AssetImage('assets/photo.jpg')),
  ],
);
```

### Elastic scroll

```dart
ElasticListView.builder(
  elasticity: 0.3,
  itemCount: 20,
  itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
);
```

### Shake

`ShakeToAction` triggers when the user makes a fast back-and-forth drag on the widget.
It is gesture based; it does not read the accelerometer. You can also trigger the
animation from code with a `ShakeController`:

```dart
final shake = ShakeController();

ShakeToAction(
  controller: shake,
  onShake: undoLastAction,
  child: Card(child: Text('Shake me')),
);

// Later, from code:
shake.shake();
```

`ShakeButton` shakes when a press is not valid, for example on a form error:

```dart
ShakeButton(
  isValid: formIsValid,
  onPressed: submit,
  builder: (context, handlePressed) =>
      ElevatedButton(onPressed: handlePressed, child: const Text('Submit')),
);
```

### Morphing shapes

```dart
MorphingShapes(
  shapes: [MicroShapeType.circle, MicroShapeType.square, MicroShapeType.star],
  autoPlay: true,
);
```

Use a `MorphingShapesController` to change shapes from code.

### Page transitions

```dart
Navigator.of(context).push(
  MicroPageRoute(type: MicroTransitionType.slideLeft, child: DetailScreen()),
);

// Or with the helper
MicroNavigator.push(context, DetailScreen(), type: MicroTransitionType.fade);
```

Available types: `fade`, `slideRight`, `slideLeft`, `slideTop`, `slideBottom`,
`scale`, `rotate`, `size`, `flip`, `blur`.

### Loading skeletons

```dart
SkeletonLoader(
  loading: isLoading,
  skeleton: CardSkeleton(hasImage: true, titleLines: 1, subtitleLines: 2),
  child: MyCard(),
);
```

When you show many skeletons at once, wrap them in a `SkeletonScope` so they
share one synchronized shimmer animation:

```dart
SkeletonScope(
  child: ListView(
    children: [for (var i = 0; i < 10; i++) const ListItemSkeleton()],
  ),
);
```

### Toast notifications

```dart
context.showToast(
  message: 'Saved successfully',
  type: ToastType.success,
);

// With more options
context.showToast(
  message: 'Connection lost',
  type: ToastType.error,
  position: ToastPosition.bottom,
  actionLabel: 'Retry',
  onAction: reconnect,
);
```

Toasts stack when several are visible, animate in and out, and are announced
to screen readers. Users can swipe a toast away (`swipeToDismiss`), and
`showProgress` draws a thin countdown bar that pauses on hover or press.

### Card flip

```dart
CardFlip(
  front: Card(child: Text('Front')),
  back: Card(child: Text('Back')),
);
```

Tap flips the card by default. Use a `CardFlipController` for programmatic
control, or pass `isFlipped` to control it from your own state.

### Success burst

A one-shot particle burst for confirmations. Trigger it from code with a
controller, or let a tap trigger it:

```dart
final burst = SuccessBurstController();

SuccessBurst(
  controller: burst,
  child: Icon(Icons.check_circle, size: 48),
);

// After a successful action:
burst.burst();
```

### Pulse highlight

Draw attention to a widget with expanding pulse rings, for example during
onboarding:

```dart
PulseHighlight(
  maxPulseCount: 5,
  child: IconButton(icon: Icon(Icons.settings), onPressed: openSettings),
);
```

The pulse stops when the user taps the widget. Use a `PulseHighlightController`
to start and stop it from code.

### Animated counter

```dart
// Numeric count from the old value to the new one
AnimatedCounter(value: total);

// Odometer style: changed digits slide into place
AnimatedCounter(value: total, mode: CounterAnimationMode.slideDigits);

// Built-in formatting: $1,249.50
AnimatedCounter(value: price, prefix: '\$', fractionDigits: 2, thousandsSeparator: ',');
```

### Animated badge

A count badge attached to a corner of a widget. It appears, disappears, and
bounces on changes:

```dart
AnimatedBadge(
  count: cartItems.length,
  child: Icon(Icons.shopping_cart),
);
```

### Staggered list

Children animate in one after another the first time they appear:

```dart
StaggeredList(
  children: [for (final item in items) ListTile(title: Text(item))],
);
```

Use `StaggeredList.builder` for long lists, or wrap items of any custom layout
in `StaggeredItem`.

### Shimmer button

A call-to-action button with a periodic shimmer sweep:

```dart
ShimmerButton(
  onPressed: checkout,
  child: Text('Checkout'),
);
```

### Slide to confirm

A slide control for actions that deserve friction, such as payments or
deletions. Screen reader and keyboard users can confirm directly:

```dart
SlideToConfirm(
  label: 'Slide to pay',
  onConfirmed: processPayment,
);
```

For async work, use `onConfirmAsync`. The thumb shows a spinner and the
control stays locked until the `Future` completes. Errors spring the thumb
back and go to `onError`:

```dart
SlideToConfirm(
  label: 'Slide to publish',
  onConfirmAsync: () => api.publish(),
);
```

### Hold to confirm

Press and hold to fill the button; releasing early drains it:

```dart
HoldToConfirm(
  onConfirmed: deleteProject,
  fillStyle: HoldFillStyle.liquid,
  child: Text('Hold to delete'),
);
```

### Expandable floating action button

A floating action button that expands into a set of actions, in a line or
in an arc:

```dart
ExpandableFab(
  direction: ExpandableFabDirection.radial,
  actions: [
    ExpandableFabAction(icon: Icon(Icons.edit), label: 'Edit', onPressed: edit),
    ExpandableFabAction(icon: Icon(Icons.share), label: 'Share', onPressed: share),
  ],
);
```

### Animated check

A checkmark or cross drawn stroke by stroke, for the end of a loading flow:

```dart
AnimatedCheck(type: AnimatedCheckType.check, onCompleted: close);
```

### Animated gradient border

```dart
AnimatedGradientBorder(
  child: Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Featured'))),
);
```

### Typewriter text

```dart
TypewriterText(
  strings: ['Build faster.', 'Animate with one widget.'],
  loop: true,
);
```

### Liquid progress

```dart
LiquidProgress(
  value: downloadProgress,
  showPercentage: true,
);
```

## Accessibility

- All animations respect the platform "reduce motion" setting. Decorative
  animations stop, and transitions become instant.
- Interactive widgets are exposed as buttons to screen readers and can be
  activated with Enter or Space.
- Toasts and button state changes are announced to screen readers.
- Swipe and long press actions are available as custom accessibility actions.

## Migration from 0.0.x

Version 0.1.0 renames classes that conflicted with the Flutter SDK and other
popular packages, and replaces fragile APIs with controllers.

| Before | After |
| --- | --- |
| `ReorderableList` | `MicroReorderableList` |
| `PageTransition` | `MicroPageRoute` |
| `PageTransitionType` | `MicroTransitionType` |
| `TransitionRoute` | `MicroNavigator` helpers |
| `SwipeAction` | `MicroSwipeAction` (factories take `context`) |
| `MenuItem` | `LongPressMenuItem` |
| `ShapeType` | `MicroShapeType` |
| `ButtonState` | `MicroButtonState` |
| `ButtonStates.withTransitions` | `ButtonStates` with `ButtonStateController` |
| `SharedAxisTransition`, `HeroTransition` | Removed |
| `withCardFlip`, `ReorderableListExtension` | Removed |

See the changelog for the full list of changes.

## Example

The example app shows every widget in action:

```bash
cd example
flutter run
```

## Credits

`BorderBeam`, `ThinkingOrb` and `VoiceGlow` are Flutter ports of Border Beam,
Thinking Orbs and Voice from [libraries.dev](https://libraries.dev) by
Jakub Antalik, released under the MIT license (see THIRD_PARTY_NOTICES). Several text and
pointer effects are inspired by [React Bits](https://reactbits.dev).

## License

See the LICENSE file.

## Support

If you find this package useful, you can support its development here:
[buymeacoffee.com/dvillegas](https://coff.ee/dvillegas)
