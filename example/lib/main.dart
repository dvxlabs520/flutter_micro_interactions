import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import 'pages/buttons_inputs_page.dart';
import 'pages/counters_celebration_page.dart';
import 'pages/feedback_page.dart';
import 'pages/gestures_page.dart';
import 'pages/highlights_overlays_page.dart';
import 'pages/lists_scroll_page.dart';
import 'pages/progress_confirmation_page.dart';
import 'pages/loading_page.dart';
import 'pages/shapes_transitions_page.dart';

void main() {
  runApp(const MicroInteractionsExampleApp());
}

class MicroInteractionsExampleApp extends StatelessWidget {
  const MicroInteractionsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Micro Interactions',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// One entry of the home screen: a demo category with the transition used
/// to open it, so navigation itself showcases MicroPageRoute.
class _DemoCategory {
  const _DemoCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.transition,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final MicroTransitionType transition;
  final WidgetBuilder builder;
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final List<_DemoCategory> _categories = [
    _DemoCategory(
      title: 'Gestures & Taps',
      subtitle: 'TapFeedback, HoverGlow, RippleEffect, '
          'LongPressMenu, ShakeToAction',
      icon: Icons.touch_app,
      transition: MicroTransitionType.slideRight,
      builder: (context) => const GesturesPage(),
    ),
    _DemoCategory(
      title: 'Buttons & Inputs',
      subtitle: 'ButtonStates, ShakeButton, ShimmerButton, InputFocus, '
          'FloatingLabel',
      icon: Icons.smart_button,
      transition: MicroTransitionType.fade,
      builder: (context) => const ButtonsInputsPage(),
    ),
    _DemoCategory(
      title: 'Lists & Scroll',
      subtitle: 'PullToRefresh, SwipeActions, MicroReorderableList, '
          'ElasticListView, ParallaxScroll, StaggeredList',
      icon: Icons.list_alt,
      transition: MicroTransitionType.slideBottom,
      builder: (context) => const ListsScrollPage(),
    ),
    _DemoCategory(
      title: 'Feedback & Toasts',
      subtitle: 'ToastNotification and the showToast extension',
      icon: Icons.notifications_active,
      transition: MicroTransitionType.scale,
      builder: (context) => const FeedbackPage(),
    ),
    _DemoCategory(
      title: 'Counters & Celebration',
      subtitle: 'SuccessBurst, PulseHighlight, AnimatedCounter, '
          'AnimatedBadge',
      icon: Icons.celebration,
      transition: MicroTransitionType.slideLeft,
      builder: (context) => const CountersCelebrationPage(),
    ),
    _DemoCategory(
      title: 'Progress & Confirmation',
      subtitle: 'SlideToConfirm, LiquidProgress, AnimatedCheck',
      icon: Icons.task_alt,
      transition: MicroTransitionType.slideTop,
      builder: (context) => const ProgressConfirmationPage(),
    ),
    _DemoCategory(
      title: 'Highlights & Overlays',
      subtitle: 'TypewriterText, AnimatedGradientBorder, ExpandableFab',
      icon: Icons.auto_awesome,
      transition: MicroTransitionType.flip,
      builder: (context) => const HighlightsOverlaysPage(),
    ),
    _DemoCategory(
      title: 'Shapes & Transitions',
      subtitle: 'MorphingShapes, CardFlip, MicroPageRoute',
      icon: Icons.transform,
      transition: MicroTransitionType.blur,
      builder: (context) => const ShapesTransitionsPage(),
    ),
    _DemoCategory(
      title: 'Loading',
      subtitle: 'LoadingSkeleton, SkeletonScope, SkeletonLoader',
      icon: Icons.hourglass_top,
      transition: MicroTransitionType.size,
      builder: (context) => const LoadingPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Micro Interactions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Micro-interaction widgets, grouped by category. Each card opens '
            'its demos with a different MicroPageRoute transition.',
            style: textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final _DemoCategory category in _categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              // The home cards themselves use TapFeedback from the package.
              child: TapFeedback.scale(
                onTap: () {
                  MicroNavigator.push(
                    context,
                    category.builder(context),
                    type: category.transition,
                  );
                },
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            category.icon,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(category.title,
                                  style: textTheme.titleMedium),
                              const SizedBox(height: 4),
                              Text(
                                category.subtitle,
                                style: textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
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
