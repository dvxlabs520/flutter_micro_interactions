import 'package:flutter/material.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

/// Demos for the loading skeleton family: LoadingSkeleton, TextSkeleton,
/// CardSkeleton, ListItemSkeleton, GridItemSkeleton, SkeletonScope and
/// SkeletonLoader.
class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loading'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = !_isLoading;
                });
              },
              icon: Icon(_isLoading ? Icons.visibility : Icons.hourglass_top),
              label: Text(_isLoading ? 'Show content' : 'Show skeletons'),
            ),
          ),
        ],
      ),
      // SkeletonScope shares one shimmer animation across every descendant
      // skeleton so they animate in sync with a single ticker.
      body: SkeletonScope(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'SkeletonLoader cross-fades between a skeleton and the real '
              'content. Toggle the switch in the app bar to compare.',
              style: textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('CardSkeleton', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SkeletonLoader(
              loading: _isLoading,
              skeleton: const CardSkeleton(imageHeight: 100),
              child: Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 100,
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.article, size: 48),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quarterly report published',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('The finance team shared the Q2 summary with '
                              'revenue and growth highlights.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('ListItemSkeleton', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            for (int index = 0; index < 3; index++)
              SkeletonLoader(
                loading: _isLoading,
                skeleton: const ListItemSkeleton(hasTrailing: true),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Colors.primaries[index * 4 % Colors.primaries.length],
                    child: Text('${index + 1}'),
                  ),
                  title: Text('Team update ${index + 1}'),
                  subtitle: const Text('Loaded from the network'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            const SizedBox(height: 24),
            Text('GridItemSkeleton', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                for (int index = 0; index < 2; index++)
                  Expanded(
                    child: SkeletonLoader(
                      loading: _isLoading,
                      skeleton:
                          const GridItemSkeleton(imageAspectRatio: 4 / 3),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 4 / 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.photo, size: 40),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Photo ${index + 1}'),
                            const Text(
                              'Album item',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Building blocks', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The primitives the composed skeletons are built from.
                    LoadingSkeleton(width: 120, height: 120),
                    SizedBox(height: 16),
                    TextSkeleton(lines: 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
