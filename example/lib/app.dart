import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import 'catalog/registry.dart';
import 'shell/shell.dart';
import 'theme/app_theme.dart';

/// A place in the gallery: the overview, a category or a component.
sealed class AppRoute {
  const AppRoute();

  /// Used as the key of the page and in the URL fragment.
  String get path;
}

class HomeRoute extends AppRoute {
  const HomeRoute();

  @override
  String get path => '/';
}

/// The full index of components.
class IndexRoute extends AppRoute {
  const IndexRoute();

  @override
  String get path => '/components';
}

/// Installation and first steps.
class GetStartedRoute extends AppRoute {
  const GetStartedRoute();

  @override
  String get path => '/get-started';
}

class CategoryRoute extends AppRoute {
  const CategoryRoute(this.category);

  final Category category;

  @override
  String get path => '/category/${category.id}';
}

class ComponentRoute extends AppRoute {
  const ComponentRoute(this.entry);

  final ComponentEntry entry;

  @override
  String get path => '/components/${entry.id}';
}

/// A scroll offset to open the first page at, from `?y=` in the start URL
/// (for example `/#/?y=2400`). Used to review long pages.
double? initialScrollOffset;

/// Turns animations off for the whole app, from `?still=1` in the start
/// URL. Used for static screenshots of long pages.
bool stillMode = false;

/// Parses a path written by [AppRoute.path].
AppRoute routeFromPath(String path) {
  final Uri uri = Uri.parse(path);
  initialScrollOffset ??= double.tryParse(uri.queryParameters['y'] ?? '');
  if (uri.queryParameters['still'] == '1') stillMode = true;
  path = uri.path;
  final List<String> parts = path
      .split('/')
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length == 2 && parts[0] == 'components') {
    final ComponentEntry? entry = Catalog.byId(parts[1]);
    if (entry != null) return ComponentRoute(entry);
  }
  if (parts.length == 1 && parts[0] == 'components') return const IndexRoute();
  if (parts.length == 1 && parts[0] == 'get-started') {
    return const GetStartedRoute();
  }
  if (parts.length == 2 && parts[0] == 'category') {
    for (final Category c in Categories.components) {
      if (c.id == parts[1]) return CategoryRoute(c);
    }
  }
  return const HomeRoute();
}

/// App wide state: theme mode, current route and the search focus.
class ShowcaseController extends ChangeNotifier {
  ShowcaseController({AppRoute initialRoute = const HomeRoute()})
    : _route = initialRoute;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  AppRoute _route;

  /// The page shown in the content area on wide screens.
  AppRoute get route => _route;

  /// Whether the shell currently shows the permanent sidebar.
  bool isWide = true;

  final FocusNode searchFocus = FocusNode(debugLabel: 'search');

  /// Text of the bar's search field; it filters the component index.
  final TextEditingController searchText = TextEditingController();

  String _query = '';
  String get query => _query;

  void setQuery(String value) {
    final String next = value.trim();
    if (value.isEmpty && searchText.text.isNotEmpty) searchText.clear();
    if (next == _query) return;
    _query = next;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    notifyListeners();
  }

  void go(AppRoute route) {
    if (route.path == _route.path) return;
    _route = route;
    notifyListeners();
  }

  @override
  void dispose() {
    searchFocus.dispose();
    searchText.dispose();
    super.dispose();
  }
}

/// Gives descendants access to the [ShowcaseController].
class Showcase extends InheritedNotifier<ShowcaseController> {
  const Showcase({
    super.key,
    required ShowcaseController controller,
    required super.child,
  }) : super(notifier: controller);

  static ShowcaseController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Showcase>()!.notifier!;

  /// Reads the controller without listening to it.
  static ShowcaseController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<Showcase>()!.notifier!;
}

/// Opens [route]: in place on wide screens, as a pushed page with a
/// [MicroPageRoute] transition on narrow ones.
void openRoute(BuildContext context, AppRoute route, {bool replace = false}) {
  final ShowcaseController controller = Showcase.read(context);
  if (controller.isWide) {
    controller.go(route);
    return;
  }
  final NavigatorState navigator = Navigator.of(context);
  if (route is HomeRoute) {
    navigator.popUntil((r) => r.isFirst);
    return;
  }
  final Widget page = NarrowPage(route: route);
  if (replace) {
    navigator.pushReplacement(
      MicroPageRoute<void>(
        child: page,
        type: MicroTransitionType.fade,
        duration: const Duration(milliseconds: 220),
      ),
    );
  } else {
    navigator.push(
      MicroPageRoute<void>(
        child: page,
        type: MicroTransitionType.slideLeft,
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

/// The gallery app.
class ShowcaseApp extends StatefulWidget {
  const ShowcaseApp({super.key, this.initialPath});

  /// Opens this path on start, for example `/components/border-beam`.
  final String? initialPath;

  @override
  State<ShowcaseApp> createState() => _ShowcaseAppState();
}

class _ShowcaseAppState extends State<ShowcaseApp> with WidgetsBindingObserver {
  late final ShowcaseController _controller = ShowcaseController(
    initialRoute: routeFromPath(widget.initialPath ?? '/'),
  );

  @override
  void initState() {
    super.initState();
    // Registered before MaterialApp's own observer, so URL changes (for
    // example editing the fragment on the web) are handled here instead of
    // pushing a named route.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async {
    _controller.go(routeFromPath(info.uri.path));
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => MaterialApp(
        title: 'Micro Interactions for Flutter',
        color: const Color(0xFF0D7480),
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _controller.themeMode,
        themeAnimationDuration: const Duration(milliseconds: 260),
        builder: (context, navigator) {
          Widget child = Showcase(controller: _controller, child: navigator!);
          if (stillMode) {
            child = MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child,
            );
          }
          return child;
        },
        // The shell owns navigation inside the gallery; the initial path is
        // parsed by ShowcaseController instead of the Navigator.
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(builder: (_) => const ShowcaseShell()),
        ],
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => const ShowcaseShell()),
      ),
    );
  }
}
