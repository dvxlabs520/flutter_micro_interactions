import 'package:flutter/material.dart';

import '../app.dart';
import '../catalog/registry.dart';
import '../shared/code_view.dart';
import '../shared/page_scaffold.dart';
import '../shared/ui.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Installation, a first widget and how motion is reduced.
class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScroll(
      top: 64,
      builder: (context, width) {
        final bool wide = width >= 900;
        Widget step(String title, String text, Widget proof) {
          final Widget words = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppType.lead(context)),
              const SizedBox(height: 10),
              Text(text, style: AppType.body(context)),
            ],
          );
          return Reveal(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: words),
                      const SizedBox(width: 48),
                      Expanded(flex: 7, child: proof),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [words, const SizedBox(height: 20), proof],
                  ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Reveal(child: Text('GET STARTED', style: AppType.head(context))),
            const SizedBox(height: 16),
            Reveal(
              order: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  'Three steps, about a minute. The package needs Flutter '
                  '3.44 or newer and nothing else.',
                  style: AppType.lead(context),
                ),
              ),
            ),
            const SizedBox(height: 80),
            step(
              'Add the package',
              'Run this in your project folder. It adds the latest version '
                  'to your pubspec.',
              const CodeView(code: installCommand),
            ),
            const SizedBox(height: 72),
            step(
              'Wrap a widget',
              'Every component wraps or replaces one widget. Here a card '
                  'gets a border beam while an agent works, and loses it when '
                  'the work is done.',
              const CodeView(
                code:
                    "import 'package:flutter_micro_interactions/"
                    "flutter_micro_interactions.dart';\n\n"
                    'BorderBeam(\n'
                    '  active: isWorking,\n'
                    '  borderRadius: BorderRadius.circular(16),\n'
                    '  child: const AgentCard(),\n'
                    ')',
              ),
            ),
            const SizedBox(height: 72),
            step(
              'Leave reduced motion on',
              'When the user asks the system for less motion, every widget '
                  'shows its final state at once. You can read the same '
                  'setting for your own animations.',
              const CodeView(
                code:
                    'final bool calm = MicroMotion.isReduced(context);\n'
                    'final Duration d = MicroMotion.effectiveDuration(\n'
                    '  context,\n'
                    '  const Duration(milliseconds: 300),\n'
                    ');',
              ),
            ),
            const SizedBox(height: 96),
            Wrap(
              spacing: 32,
              runSpacing: 12,
              children: [
                TextLink(
                  label: 'Browse all ${Catalog.count} components',
                  onTap: () => openRoute(context, const IndexRoute()),
                  style: AppType.lead(context),
                  restColor: Palette.of(context).ink,
                ),
                if (Catalog.ordered.isNotEmpty)
                  TextLink(
                    label: 'Open ${Catalog.ordered.first.name}',
                    onTap: () => openRoute(
                      context,
                      ComponentRoute(Catalog.ordered.first),
                    ),
                    style: AppType.lead(context),
                    restColor: Palette.of(context).ink,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
