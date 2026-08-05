# Flutter Micro Interactions

A collection of ready-to-use micro-interactions and animations for Flutter.
Add professional motion to your app with a few lines of code.

![Preview](micro_interactions.gif)

## Why this package

- Simple API. Wrap a widget, get the animation. Every widget works with sensible defaults.
- Consistent. All widgets share the same core parameters: `duration`, `curve`, and `enabled`.
- Accessible. The package respects the platform "reduce motion" setting, announces state
  changes to screen readers, and supports keyboard focus and activation.
- Safe. Widgets react to configuration changes, clean up their resources, and are guarded
  against use after dispose.
- No extra dependencies. Only Flutter.

## Requirements

Flutter 3.38 or newer.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_micro_interactions: ^0.2.0
```

Then import it:

```dart
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';
```

## Widgets

| Widget | What it does |
| --- | --- |
| `TapFeedback` | Scale, bounce, or fade feedback on tap |
| `ButtonStates` | Loading, success, and error states for any button |
| `HoverGlow` | Glow effect on hover and keyboard focus |
| `InputFocus` | Lift and scale effect when an input gains focus |
| `FloatingLabel` | Text field with an animated floating label and validation |
| `RippleEffect`, `RippleButton`, `WaterRipple` | Ripple animations |
| `PullToRefresh` | Pull-to-refresh with Material or adaptive indicator |
| `SwipeActions` | Swipe a list item to reveal tappable actions |
| `MicroReorderableList` | Drag and drop reordering with a lift effect |
| `LongPressMenu` | Context menu on long press |
| `ParallaxScroll`, `ParallaxImage` | Parallax scrolling effects |
| `ElasticScroll`, `ElasticListView`, `ElasticGridView` | Elastic overscroll |
| `ShakeToAction`, `ShakeAnimation`, `ShakeButton` | Shake animations and gestures |
| `MorphingShapes`, `ShapeMorph` | Smooth morphing between shapes |
| `MicroPageRoute`, `MicroNavigator` | Page transitions (fade, slide, scale, flip, blur, and more) |
| `LoadingSkeleton`, `TextSkeleton`, `CardSkeleton`, `ListItemSkeleton`, `GridItemSkeleton`, `SkeletonLoader` | Loading skeletons with shimmer |
| `ToastNotification` | Animated toast notifications |
| `CardFlip` | 3D card flip |
| `SuccessBurst` | Particle burst for success confirmations |
| `PulseHighlight` | Pulse rings that draw attention to a widget |
| `AnimatedCounter` | Animated number changes, with an odometer mode |
| `AnimatedBadge` | Count badge that bounces when the count changes |
| `StaggeredList`, `StaggeredItem` | Staggered entrance animation for lists |
| `ShimmerButton` | Call-to-action button with a shimmer sweep |
| `SlideToConfirm` | Slide a thumb across a track to confirm an action |
| `ExpandableFab` | Floating button that expands into a set of actions |
| `AnimatedCheck` | Checkmark or cross drawn with an animated stroke |
| `AnimatedGradientBorder` | Animated sweeping gradient border |
| `TypewriterText` | Text that types itself out, with cursor and looping |
| `LiquidProgress` | Progress indicator filled with an animated wave |

## Usage

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

Every child needs a key. The `onReorder` callback follows the standard Flutter convention:

```dart
MicroReorderableList(
  onReorder: (oldIndex, newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
    });
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
to screen readers.

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

## License

See the LICENSE file.

## Support

If you find this package useful, you can support its development here:
[buymeacoffee.com/dvillegas](https://coff.ee/dvillegas)
