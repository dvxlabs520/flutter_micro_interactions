import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'utils/motion.dart';

/// The possible visual states of a [ButtonStates] widget.
enum MicroButtonState {
  /// The resting state; the original child is shown.
  idle,

  /// A loading indicator is shown.
  loading,

  /// A success indicator is shown.
  success,

  /// An error indicator is shown.
  error,
}

/// Programmatic control surface for a [ButtonStates] widget.
///
/// Create one controller per button, keep it in your State, and call
/// [setLoading], [setSuccess], [setError] or [setIdle] to drive the
/// transitions. Dispose it when you are done.
///
/// ```dart
/// final _controller = ButtonStateController();
///
/// Future<void> _save() async {
///   _controller.setLoading();
///   try {
///     await api.save();
///     _controller.setSuccess();
///   } catch (_) {
///     _controller.setError();
///   }
/// }
/// ```
///
/// [run] wraps that whole pattern, including the return to idle:
///
/// ```dart
/// Future<void> _save() => _controller.run(api.save);
/// ```
class ButtonStateController extends ChangeNotifier {
  /// Creates a controller starting in [MicroButtonState.idle].
  ButtonStateController([MicroButtonState initialState = MicroButtonState.idle])
    : _state = initialState;

  MicroButtonState _state;

  /// Incremented on every state change; lets [run] detect that the state
  /// was changed by someone else while it was waiting.
  int _generation = 0;

  /// Identifies the most recent [run] call.
  int _runToken = 0;

  Timer? _runResetTimer;
  bool _disposed = false;

  /// The current state.
  MicroButtonState get state => _state;

  /// Moves the button back to [MicroButtonState.idle].
  void setIdle() => _setState(MicroButtonState.idle);

  /// Moves the button to [MicroButtonState.loading].
  void setLoading() => _setState(MicroButtonState.loading);

  /// Moves the button to [MicroButtonState.success].
  void setSuccess() => _setState(MicroButtonState.success);

  /// Moves the button to [MicroButtonState.error].
  void setError() => _setState(MicroButtonState.error);

  /// Runs [task] while driving the button through its states.
  ///
  /// Sets [MicroButtonState.loading], awaits [task], then sets
  /// [MicroButtonState.success] when it completes or
  /// [MicroButtonState.error] when it throws. After [resetAfter] the button
  /// returns to [MicroButtonState.idle]; pass `null` to stay in the success
  /// or error state.
  ///
  /// ```dart
  /// final User? user = await controller.run(() => api.fetchUser(id));
  /// ```
  ///
  /// The state is only updated when it was not changed in the meantime:
  /// if you call [setIdle] (or any other setter, or start another [run])
  /// while [task] is pending, the result of this run no longer touches the
  /// state, and the reset after [resetAfter] is skipped when the state
  /// changed after success or error was shown. Nothing happens once the
  /// controller has been disposed, so it is safe to dispose it while
  /// [task] is pending.
  ///
  /// Returns the value produced by [task], or `null` when it throws. When
  /// [rethrowErrors] is `true` the error is rethrown to the caller (after
  /// the error state is shown) instead.
  Future<T?> run<T>(
    Future<T> Function() task, {
    Duration? resetAfter = const Duration(seconds: 2),
    bool rethrowErrors = false,
  }) async {
    assert(
      resetAfter == null || resetAfter >= Duration.zero,
      'resetAfter must not be negative',
    );
    assert(!_disposed, 'run was called on a disposed ButtonStateController');
    if (_disposed) {
      return null;
    }
    final int token = ++_runToken;
    _runResetTimer?.cancel();
    _runResetTimer = null;
    _setState(MicroButtonState.loading);
    final int startGeneration = _generation;

    try {
      final T result = await task();
      _finishRun(token, startGeneration, MicroButtonState.success, resetAfter);
      return result;
    } catch (error) {
      _finishRun(token, startGeneration, MicroButtonState.error, resetAfter);
      if (rethrowErrors) {
        rethrow;
      }
      return null;
    }
  }

  /// Applies the outcome of the [run] identified by [token], unless the
  /// controller was disposed or the state changed since [startGeneration].
  void _finishRun(
    int token,
    int startGeneration,
    MicroButtonState outcome,
    Duration? resetAfter,
  ) {
    if (_disposed || token != _runToken || _generation != startGeneration) {
      return;
    }
    _setState(outcome);
    if (resetAfter == null) {
      return;
    }
    final int outcomeGeneration = _generation;
    _runResetTimer = Timer(resetAfter, () {
      _runResetTimer = null;
      if (!_disposed && _generation == outcomeGeneration) {
        _setState(MicroButtonState.idle);
      }
    });
  }

  void _setState(MicroButtonState value) {
    if (_state == value) return;
    _state = value;
    _generation++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _runResetTimer?.cancel();
    _runResetTimer = null;
    super.dispose();
  }
}

/// Animates a button (or any widget) between idle, loading, success and
/// error content.
///
/// The widget renders [child] while idle and swaps to the widget produced
/// by [loadingBuilder], [successBuilder] or [errorBuilder] using an
/// [AnimatedSwitcher] wrapped in an [AnimatedSize], so both the content
/// and the footprint animate. The original [child] is rendered as-is; this
/// widget never rebuilds or reconstructs it.
///
/// State is driven by a [ButtonStateController]:
///
/// ```dart
/// ButtonStates(
///   controller: _controller,
///   child: ElevatedButton(
///     onPressed: _save,
///     child: const Text('Save'),
///   ),
/// )
/// ```
///
/// Each state change is announced to assistive technology. When the
/// platform requests reduced motion the swap happens instantly.
class ButtonStates extends StatefulWidget {
  /// Creates a state-transition wrapper driven by [controller].
  const ButtonStates({
    super.key,
    required this.controller,
    required this.child,
    this.loadingBuilder,
    this.successBuilder,
    this.errorBuilder,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.autoResetDuration,
    this.onStateChanged,
  });

  /// Drives which state is shown. This widget listens to it and rebuilds
  /// on changes. The caller owns and disposes the controller.
  final ButtonStateController controller;

  /// The widget shown in [MicroButtonState.idle].
  final Widget child;

  /// Builds the loading content. Defaults to a small circular progress
  /// indicator using the theme's primary color.
  final WidgetBuilder? loadingBuilder;

  /// Builds the success content. Defaults to a check icon using the
  /// theme's primary color.
  final WidgetBuilder? successBuilder;

  /// Builds the error content. Defaults to an error icon using the
  /// theme's error color.
  final WidgetBuilder? errorBuilder;

  /// Length of the swap animation. Defaults to 300 milliseconds.
  final Duration duration;

  /// Curve of the swap animation. Defaults to [Curves.easeInOut].
  final Curve curve;

  /// When non-null, success and error states automatically revert to
  /// [MicroButtonState.idle] after this duration.
  final Duration? autoResetDuration;

  /// Called whenever the state changes, after the change is applied.
  final ValueChanged<MicroButtonState>? onStateChanged;

  @override
  State<ButtonStates> createState() => _ButtonStatesState();
}

class _ButtonStatesState extends State<ButtonStates> {
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(ButtonStates oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _resetTimer?.cancel();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final MicroButtonState state = widget.controller.state;
    setState(() {});
    _resetTimer?.cancel();
    if (widget.autoResetDuration != null &&
        (state == MicroButtonState.success ||
            state == MicroButtonState.error)) {
      _resetTimer = Timer(widget.autoResetDuration!, () {
        if (mounted) widget.controller.setIdle();
      });
    }
    _announce(state);
    widget.onStateChanged?.call(state);
  }

  void _announce(MicroButtonState state) {
    final String? message = switch (state) {
      MicroButtonState.idle => null,
      MicroButtonState.loading => 'Loading',
      MicroButtonState.success => 'Success',
      MicroButtonState.error => 'Error',
    };
    if (message == null) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Widget _defaultLoading(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(
      strokeWidth: 2.5,
      valueColor: AlwaysStoppedAnimation<Color>(
        Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _defaultSuccess(BuildContext context) =>
      Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary);

  Widget _defaultError(BuildContext context) =>
      Icon(Icons.error, color: Theme.of(context).colorScheme.error);

  Widget _currentContent(BuildContext context) {
    return switch (widget.controller.state) {
      MicroButtonState.idle => KeyedSubtree(
        key: const ValueKey<MicroButtonState>(MicroButtonState.idle),
        child: widget.child,
      ),
      MicroButtonState.loading => KeyedSubtree(
        key: const ValueKey<MicroButtonState>(MicroButtonState.loading),
        child: (widget.loadingBuilder ?? _defaultLoading)(context),
      ),
      MicroButtonState.success => KeyedSubtree(
        key: const ValueKey<MicroButtonState>(MicroButtonState.success),
        child: (widget.successBuilder ?? _defaultSuccess)(context),
      ),
      MicroButtonState.error => KeyedSubtree(
        key: const ValueKey<MicroButtonState>(MicroButtonState.error),
        child: (widget.errorBuilder ?? _defaultError)(context),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (MicroMotion.isReduced(context)) {
      // Instant swap. AnimatedSize must not be given Duration.zero: it would
      // notify listeners during its own layout and re-dirty itself.
      return _currentContent(context);
    }
    return AnimatedSize(
      duration: widget.duration,
      curve: widget.curve,
      child: AnimatedSwitcher(
        duration: widget.duration,
        switchInCurve: widget.curve,
        switchOutCurve: widget.curve,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _currentContent(context),
      ),
    );
  }
}
