import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../widgets/demo_widgets.dart';

/// Demos for PullToRefresh, SwipeActions, MicroReorderableList,
/// ElasticListView, ParallaxScroll and StaggeredList, one tab each so every
/// list can use the full height.
class ListsScrollPage extends StatelessWidget {
  const ListsScrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lists & Scroll'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Pull to refresh'),
              Tab(text: 'Swipe actions'),
              Tab(text: 'Reorder'),
              Tab(text: 'Elastic'),
              Tab(text: 'Parallax'),
              Tab(text: 'Staggered'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PullToRefreshDemo(),
            _SwipeActionsDemo(),
            _ReorderableDemo(),
            _ElasticDemo(),
            _ParallaxDemo(),
            _StaggeredDemo(),
          ],
        ),
      ),
    );
  }
}

class _PullToRefreshDemo extends StatefulWidget {
  const _PullToRefreshDemo();

  @override
  State<_PullToRefreshDemo> createState() => _PullToRefreshDemoState();
}

class _PullToRefreshDemoState extends State<_PullToRefreshDemo> {
  int _refreshCount = 0;

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _refreshCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // PullToRefresh.adaptive shows a Cupertino spinner on iOS and macOS and
    // the Material indicator elsewhere.
    return PullToRefresh.adaptive(
      onRefresh: _onRefresh,
      child: ListView.builder(
        itemCount: 20,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text('Inbox message ${index + 1}'),
            subtitle: Text(
              _refreshCount == 0
                  ? 'Pull down to refresh'
                  : 'Refreshed $_refreshCount time(s)',
            ),
          );
        },
      ),
    );
  }
}

class _SwipeActionsDemo extends StatefulWidget {
  const _SwipeActionsDemo();

  @override
  State<_SwipeActionsDemo> createState() => _SwipeActionsDemoState();
}

class _SwipeActionsDemoState extends State<_SwipeActionsDemo> {
  final List<String> _items =
      List.generate(12, (index) => 'Email ${index + 1}');

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final String item = _items[index];
        return SwipeActions(
          // Factory constructors read their colors from the theme, so they
          // take the BuildContext first.
          leftActions: [
            MicroSwipeAction.favorite(
              context,
              onPressed: () => showMessage(context, 'Favorited $item'),
            ),
            MicroSwipeAction.archive(
              context,
              onPressed: () => showMessage(context, 'Archived $item'),
            ),
          ],
          rightActions: [
            MicroSwipeAction.share(
              context,
              onPressed: () => showMessage(context, 'Shared $item'),
            ),
            MicroSwipeAction.delete(
              context,
              onPressed: () {
                setState(() {
                  _items.remove(item);
                });
              },
            ),
          ],
          child: ListTile(
            tileColor: Theme.of(context).colorScheme.surface,
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(item),
            subtitle: const Text('Swipe left or right for actions'),
          ),
        );
      },
    );
  }
}

class _ReorderableDemo extends StatefulWidget {
  const _ReorderableDemo();

  @override
  State<_ReorderableDemo> createState() => _ReorderableDemoState();
}

class _ReorderableDemoState extends State<_ReorderableDemo> {
  final List<String> _tasks = [
    'Review pull request',
    'Update documentation',
    'Fix login bug',
    'Prepare release notes',
    'Refactor settings page',
    'Write widget tests',
    'Plan next sprint',
  ];

  @override
  Widget build(BuildContext context) {
    return MicroReorderableList(
      showDragHandle: true,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          // Indexes follow the Flutter SDK convention.
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final String task = _tasks.removeAt(oldIndex);
          _tasks.insert(newIndex, task);
        });
      },
      children: [
        // Every child of MicroReorderableList must have a key.
        for (int i = 0; i < _tasks.length; i++)
          ListTile(
            key: ValueKey(_tasks[i]),
            title: Text(_tasks[i]),
            subtitle: Text('Priority ${i + 1}'),
          ),
      ],
    );
  }
}

class _ElasticDemo extends StatelessWidget {
  const _ElasticDemo();

  @override
  Widget build(BuildContext context) {
    // ElasticListView.builder applies ElasticScrollPhysics; overscroll past
    // either edge and release to feel the spring.
    return ElasticListView.builder(
      itemCount: 30,
      elasticity: 0.5,
      itemBuilder: (context, index) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.primaries[index % Colors.primaries.length],
            child: Text('${index + 1}'),
          ),
          title: Text('Elastic item ${index + 1}'),
          subtitle: const Text('Overscroll the edges to feel the bounce'),
        );
      },
    );
  }
}

class _ParallaxDemo extends StatelessWidget {
  const _ParallaxDemo();

  @override
  Widget build(BuildContext context) {
    // The background pans slower than the list, creating depth. Extra layers
    // each have their own parallax factor.
    return ParallaxScroll(
      parallaxFactor: 0.5,
      background: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3A1C71), Color(0xFF6750A4), Color(0xFF2193B0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      layers: const [
        ParallaxLayer(
          parallaxFactor: 0.2,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 72),
              child: Text(
                'Parallax',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
      children: [
        const SizedBox(height: 180),
        for (int index = 0; index < 20; index++)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text('Scroll item ${index + 1}'),
              subtitle: const Text('Watch the background move slower'),
            ),
          ),
      ],
    );
  }
}

class _StaggeredDemo extends StatefulWidget {
  const _StaggeredDemo();

  @override
  State<_StaggeredDemo> createState() => _StaggeredDemoState();
}

class _StaggeredDemoState extends State<_StaggeredDemo> {
  StaggerEffect _effect = StaggerEffect.fadeSlideUp;

  /// Bumped by the replay button; a new key remounts the list so the
  /// entrance plays again.
  int _generation = 0;

  static const List<(String, IconData)> _contacts = [
    ('Alice Bennett', Icons.person),
    ('Bruno Carvalho', Icons.person),
    ('Chen Wei', Icons.person),
    ('Daniela Rossi', Icons.person),
    ('Emeka Obi', Icons.person),
    ('Farah Khan', Icons.person),
    ('Gustav Lindqvist', Icons.person),
    ('Hana Sato', Icons.person),
    ('Ines Duarte', Icons.person),
    ('Jonas Weber', Icons.person),
    ('Katya Petrova', Icons.person),
    ('Liam Murphy', Icons.person),
  ];

  void _replay() {
    setState(() {
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<StaggerEffect>(
                  segments: const [
                    ButtonSegment(
                      value: StaggerEffect.fadeSlideUp,
                      label: Text('Slide up'),
                    ),
                    ButtonSegment(
                      value: StaggerEffect.fadeSlideStart,
                      label: Text('From start'),
                    ),
                    ButtonSegment(
                      value: StaggerEffect.scale,
                      label: Text('Scale'),
                    ),
                  ],
                  selected: {_effect},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _effect = selection.first;
                      _generation++;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _replay,
                icon: const Icon(Icons.replay),
                tooltip: 'Replay entrance',
              ),
            ],
          ),
        ),
        Expanded(
          // The key remounts the list on replay or effect change, so the
          // staggered entrance plays from the start.
          child: StaggeredList.builder(
            key: ValueKey<String>('staggered-$_generation-$_effect'),
            itemCount: _contacts.length,
            effect: _effect,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final (String name, IconData icon) = _contacts[index];
              return ListTile(
                leading: CircleAvatar(child: Icon(icon)),
                title: Text(name),
                subtitle: Text('Contact ${index + 1} of ${_contacts.length}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
