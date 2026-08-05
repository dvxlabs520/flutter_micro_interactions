#!/usr/bin/env bash
# Publish flutter_micro_interactions to pub.dev and push the release branch/tag.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(dart pub deps --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['root']['version'])" 2>/dev/null || \
  rg -n '^version:' pubspec.yaml | head -1 | awk '{print $2}')"

echo "==> flutter_micro_interactions ${VERSION}"
echo "==> analyze + test"
flutter analyze
flutter test

echo "==> dry-run"
dart pub publish --dry-run

echo "==> publish to pub.dev"
dart pub publish --force

echo "==> push git + tag v${VERSION}"
git push -u origin HEAD
if ! git rev-parse "v${VERSION}" >/dev/null 2>&1; then
  git tag -a "v${VERSION}" -m "flutter_micro_interactions ${VERSION}"
fi
git push origin "v${VERSION}"

echo "Done. Package: https://pub.dev/packages/flutter_micro_interactions/versions/${VERSION}"
