import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Reports presses on [child] from raw pointer events.
///
/// Unlike a [GestureDetector], this widget never enters the gesture arena,
/// so it reports a press immediately and reliably even when a descendant
/// (a button) or an ancestor (a scroll view) also handles the pointer.
/// That makes it the right tool for visual press feedback, which must not
/// depend on who wins the tap.
///
/// A press ends as completed when the pointer is lifted without moving
/// beyond the platform touch slop, and as cancelled when it moves further
/// (for example because the user starts scrolling) or the pointer is
/// cancelled. Only the first pointer of a multi-touch is tracked.
///
/// This is an internal helper of the package and is not exported.
class MicroPressListener extends StatefulWidget {
  /// Creates a press listener.
  const MicroPressListener({
    super.key,
    required this.child,
    this.onPressStart,
    this.onPressEnd,
    this.enabled = true,
  });

  /// The widget whose presses are reported.
  final Widget child;

  /// Called on pointer down with the local position of the press.
  final ValueChanged<Offset>? onPressStart;

  /// Called once per press: `true` when the press completed as a tap,
  /// `false` when it was cancelled.
  final ValueChanged<bool>? onPressEnd;

  /// When false no presses are reported.
  final bool enabled;

  @override
  State<MicroPressListener> createState() => _MicroPressListenerState();
}

class _MicroPressListenerState extends State<MicroPressListener> {
  int? _pointer;
  Offset _downPosition = Offset.zero;
  double _slop = kTouchSlop;

  @override
  void didUpdateWidget(MicroPressListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pointer != null) {
      _end(false);
    }
  }

  void _handleDown(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    // Secondary mouse buttons do not press.
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    _pointer = event.pointer;
    _downPosition = event.position;
    _slop = computeHitSlop(
      event.kind,
      MediaQuery.maybeGestureSettingsOf(context),
    );
    widget.onPressStart?.call(event.localPosition);
  }

  void _handleMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if ((event.position - _downPosition).distance > _slop) {
      _end(false);
    }
  }

  void _handleUp(PointerUpEvent event) {
    if (event.pointer == _pointer) _end(true);
  }

  void _handleCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _end(false);
  }

  void _end(bool completed) {
    _pointer = null;
    widget.onPressEnd?.call(completed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleDown,
      onPointerMove: _handleMove,
      onPointerUp: _handleUp,
      onPointerCancel: _handleCancel,
      child: widget.child,
    );
  }
}

/// Warns in debug builds when a wrapper's own `onTap` was not called for a
/// completed press because a descendant won the tap.
///
/// Call [pressCompleted] when a press ends as a tap and [tapHandled] from
/// the wrapper's `onTap`. The check runs after the pointer event has been
/// fully dispatched, when the gesture arena has resolved.
class MicroLostTapWarning {
  /// Creates a warning helper for the widget called [widgetName].
  MicroLostTapWarning(this.widgetName);

  /// The widget named in the warning, for example `TapFeedback`.
  final String widgetName;

  bool _awaitingTap = false;
  bool _warned = false;

  /// Records that a press completed as a tap at time [pressDuration].
  void pressCompleted({required Duration pressDuration}) {
    if (!kDebugMode || _warned) return;
    // A long press may legitimately go to a long-press handler.
    if (pressDuration >= kLongPressTimeout) return;
    _awaitingTap = true;
    scheduleMicrotask(() {
      if (!_awaitingTap || _warned) return;
      _awaitingTap = false;
      _warned = true;
      debugPrint(
        '$widgetName.onTap was not called because a widget inside it '
        'handled the tap first (for example a button, an InkWell or a '
        'GestureDetector). Flutter gives a tap to the innermost handler '
        'only. Put the callback on the inner widget and leave '
        '$widgetName.onTap null; $widgetName still shows its press '
        'feedback.',
      );
    });
  }

  /// Records that the wrapper's own tap callback ran.
  void tapHandled() => _awaitingTap = false;
}
