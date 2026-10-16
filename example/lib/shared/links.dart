import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'code_view.dart';

/// External addresses used by the site.
abstract final class Links {
  static const String repo =
      'https://github.com/dvxlabs520/flutter_micro_interactions';
  static const String pubDev =
      'https://pub.dev/packages/flutter_micro_interactions';
  static const String changelog =
      'https://pub.dev/packages/flutter_micro_interactions/changelog';
  static const String license =
      'https://github.com/dvxlabs520/flutter_micro_interactions/blob/main/LICENSE';
}

/// Opens [url] in the browser, or tells the user when it cannot.
Future<void> openLink(BuildContext context, String url) async {
  final bool ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) showSiteToast(context, 'Could not open $url');
}
