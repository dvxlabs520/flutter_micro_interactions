import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../app.dart';
import '../catalog/registry.dart';
import '../pages/category_page.dart';
import '../pages/component_page.dart';
import '../pages/get_started_page.dart';
import '../pages/home_page.dart';
import '../shared/code_view.dart';
import '../shared/links.dart';
import '../shared/ui.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'index_panel.dart';

/// The page widget for [route].
Widget pageFor(AppRoute route) => switch (route) {
  HomeRoute() => const HomePage(),
  IndexRoute() => const IndexPage(),
  GetStartedRoute() => const GetStartedPage(),
  CategoryRoute(:final category) => CategoryPage(category: category),
  ComponentRoute(:final entry) => ComponentPage(entry: entry),
};

/// A short title for [route], used by the phone app bar.
String titleFor(AppRoute route) => switch (route) {
  HomeRoute() => 'Overview',
  IndexRoute() => 'Components',
  GetStartedRoute() => 'Get started',
  CategoryRoute(:final category) => category.name,
  ComponentRoute(:final entry) => entry.name,
};

bool get _isApple =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Opens the full screen search.
void openSearch(BuildContext context) {
  Navigator.of(context).push(
    MicroPageRoute<void>(
      child: const SearchPage(),
      type: MicroTransitionType.fade,
      duration: const Duration(milliseconds: 200),
    ),
  );
}

/// The responsive frame of the gallery. Wide: a plain bar on top, and on
/// every page but the home a component index on the surface tone at the
/// left. Narrow: the bar with a Menu link that opens the index in a drawer.
class ShowcaseShell extends StatefulWidget {
  const ShowcaseShell({super.key});

  @override
  State<ShowcaseShell> createState() => _ShowcaseShellState();
}

class _ShowcaseShellState extends State<ShowcaseShell> {
  /// The controller route last shown by the narrow shell. On narrow screens
  /// pages are pushed by [openRoute]; the controller route only changes on
  /// start and when the URL changes, and is pushed here.
  String _narrowPath = const HomeRoute().path;
  bool _wasWide = true;

  void _onSearchShortcut(BuildContext context) {
    final ShowcaseController controller = Showcase.read(context);
    if (controller.isWide && controller.route is! HomeRoute) {
      controller.searchFocus.requestFocus();
    } else {
      openSearch(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShowcaseController controller = Showcase.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            _onSearchShortcut(context),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _onSearchShortcut(context),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool wide = constraints.maxWidth >= Breakpoints.sidebar;
            controller.isWide = wide;
            final AppRoute route = controller.route;
            if (wide) {
              if (!_wasWide) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                });
              }
              _wasWide = true;
              _narrowPath = route.path;
              return _WideShell(route: route);
            }
            _wasWide = false;
            if (route.path != _narrowPath) {
              _narrowPath = route.path;
              if (route is! HomeRoute) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) openRoute(context, route);
                });
              }
            }
            return const _NarrowShell();
          },
        ),
      ),
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({required this.route});

  final AppRoute route;

  @override
  Widget build(BuildContext context) {
    final bool home = route is HomeRoute;
    final Widget page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Motion.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        children: [
          for (final Widget w in previous) Positioned.fill(child: w),
          if (current != null) Positioned.fill(child: current),
        ],
      ),
      child: KeyedSubtree(key: ValueKey(route.path), child: pageFor(route)),
    );
    // The home page scrolls its own bar away with the hero.
    if (home) return Scaffold(body: page);
    return Scaffold(
      body: Column(
        children: [
          SiteBar(route: route),
          Expanded(
            child: home
                ? page
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 272, child: IndexPanel()),
                      Expanded(child: page),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The plain bar on top: the wordmark, a few text links, the search field
/// on documentation pages, the theme switch, and on the home page the one
/// teal action.
class SiteBar extends StatelessWidget {
  const SiteBar({super.key, required this.route});

  final AppRoute route;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final bool home = route is HomeRoute;
    final TextStyle link = AppType.body(context).copyWith(fontSize: 16);
    return Container(
      height: 72,
      color: p.bg,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => openRoute(context, const HomeRoute()),
            child: const MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Wordmark(size: 26),
            ),
          ),
          const SizedBox(width: 48),
          TextLink(
            label: 'Components',
            selected: route is IndexRoute,
            onTap: () => openRoute(context, const IndexRoute()),
            style: link,
          ),
          const SizedBox(width: 28),
          TextLink(
            label: 'Get started',
            selected: route is GetStartedRoute,
            onTap: () => openRoute(context, const GetStartedRoute()),
            style: link,
          ),
          const SizedBox(width: 28),
          TextLink(
            label: 'pub.dev',
            onTap: () => openLink(context, Links.pubDev),
            style: link,
          ),
          const Spacer(),
          if (!home) ...[
            const SizedBox(width: 240, child: SearchField()),
            const SizedBox(width: 24),
          ],
          ThemeLink(style: link),
          if (home) ...[const SizedBox(width: 24), const AddToPubspecButton()],
        ],
      ),
    );
  }
}

/// The one teal action of the home page: copies the install command.
class AddToPubspecButton extends StatelessWidget {
  const AddToPubspecButton({super.key, this.expand = false});

  final bool expand;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: installCommand));
    if (context.mounted) {
      showSiteToast(context, 'Copied: $installCommand');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      scaleDown: 0.97,
      enableHaptics: false,
      onTap: () => _copy(context),
      child: FilledButton(
        onPressed: () => _copy(context),
        style: FilledButton.styleFrom(
          minimumSize: Size(expand ? double.infinity : 0, 44),
        ),
        child: const Text('Add to pubspec'),
      ),
    );
  }
}

/// Switches between the light and dark theme, as a plain word.
class ThemeLink extends StatelessWidget {
  const ThemeLink({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ShowcaseController controller = Showcase.of(context);
    final bool dark = controller.themeMode == ThemeMode.dark;
    return TextLink(
      label: dark ? 'Light' : 'Dark',
      onTap: controller.toggleTheme,
      style: style ?? AppType.body(context).copyWith(fontSize: 16),
    );
  }
}

/// The search field of the bar. Typing filters the component index;
/// Enter opens the first match. Focused with Cmd or Ctrl K.
class SearchField extends StatelessWidget {
  const SearchField({super.key});

  @override
  Widget build(BuildContext context) {
    final ShowcaseController controller = Showcase.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          controller.setQuery('');
          controller.searchFocus.unfocus();
        },
      },
      child: TextField(
        controller: controller.searchText,
        focusNode: controller.searchFocus,
        style: AppType.body(context).copyWith(fontSize: 15.5),
        decoration: InputDecoration(
          hintText: _isApple ? 'Search  (Cmd K)' : 'Search  (Ctrl K)',
        ),
        onChanged: controller.setQuery,
        onSubmitted: (_) {
          final List<ComponentEntry> hits = Catalog.search(controller.query);
          if (hits.isNotEmpty) {
            openRoute(context, ComponentRoute(hits.first));
            controller.setQuery('');
          }
        },
      ),
    );
  }
}

class _NarrowShell extends StatelessWidget {
  const _NarrowShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NarrowBar(),
      drawer: const Drawer(child: SafeArea(child: IndexPanel(inDrawer: true))),
      body: const HomePage(showBar: false),
    );
  }
}

/// The phone bar: wordmark, Menu, Search and the theme word.
class NarrowBar extends StatelessWidget implements PreferredSizeWidget {
  const NarrowBar({super.key, this.showMenu = true});

  final bool showMenu;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final TextStyle link = AppType.small(context).copyWith(fontSize: 15);
    final bool canPop = Navigator.of(context).canPop();
    return Material(
      color: p.bg,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (canPop)
                  TextLink(
                    label: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                    style: link,
                  )
                else
                  const Flexible(child: Wordmark(size: 16)),
                const Spacer(),
                if (showMenu && !canPop) ...[
                  TextLink(
                    label: 'Menu',
                    onTap: () => Scaffold.of(context).openDrawer(),
                    style: link,
                  ),
                  const SizedBox(width: 14),
                ],
                TextLink(
                  label: 'Search',
                  onTap: () => openSearch(context),
                  style: link,
                ),
                const SizedBox(width: 14),
                ThemeLink(style: link),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A pushed page on narrow screens.
class NarrowPage extends StatelessWidget {
  const NarrowPage({super.key, required this.route});

  final AppRoute route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: const NarrowBar(), body: pageFor(route));
  }
}

/// Full screen search.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final List<ComponentEntry> results = _query.isEmpty
        ? Catalog.ordered
        : Catalog.search(_query);
    final double margin = pageMargin(MediaQuery.sizeOf(context).width);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, 16, margin, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      style: AppType.body(context),
                      decoration: const InputDecoration(
                        hintText: 'Search components',
                      ),
                      onChanged: (v) => setState(() => _query = v),
                      onSubmitted: (_) {
                        if (results.isNotEmpty) {
                          openRoute(
                            context,
                            ComponentRoute(results.first),
                            replace: true,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextLink(
                    label: 'Close',
                    onTap: () => Navigator.of(context).maybePop(),
                    style: AppType.small(context).copyWith(fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: results.isEmpty
                    ? Text(
                        'Nothing matches "$_query" yet.',
                        style: AppType.body(context),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final ComponentEntry e = results[i];
                          return ToneButton(
                            onTap: () => openRoute(
                              context,
                              ComponentRoute(e),
                              replace: true,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    e.name,
                                    style: AppType.body(context),
                                  ),
                                ),
                                Text(
                                  e.category.name,
                                  style: AppType.small(context),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
