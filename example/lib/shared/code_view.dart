import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_micro_interactions/flutter_micro_interactions.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// A code block with Dart syntax highlighting and a plain Copy button, on
/// the surface tone. The only place where monospace type appears.
class CodeView extends StatelessWidget {
  const CodeView({super.key, required this.code, this.maxHeight});

  final String code;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(context);
    final _CodeColors colors = _CodeColors.of(p);
    final TextStyle base = AppFonts.mono(
      TextStyle(fontSize: 14, height: 1.65, color: p.ink),
    );
    Widget body = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: SelectableText.rich(
        TextSpan(style: base, children: _highlight(code, colors)),
      ),
    );
    if (maxHeight != null) {
      body = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: SingleChildScrollView(child: body),
      );
    }
    return Container(
      decoration: BoxDecoration(color: p.surface, borderRadius: kCorners),
      child: Stack(
        children: [
          Padding(padding: const EdgeInsets.only(right: 72), child: body),
          Positioned(top: 10, right: 10, child: CopyButton(text: code)),
        ],
      ),
    );
  }
}

/// A plain "Copy" text button that copies [text] and confirms with the
/// package's toast.
class CopyButton extends StatefulWidget {
  const CopyButton({
    super.key,
    required this.text,
    this.label = 'Copy',
    this.toastMessage = 'Copied to the clipboard',
    this.style,
  });

  final String text;
  final String label;
  final String toastMessage;
  final TextStyle? style;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    showSiteToast(context, widget.toastMessage);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextLink(
      label: _copied ? 'Copied' : widget.label,
      onTap: _copy,
      style: widget.style ?? AppType.small(context),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}

/// The site's confirmation toast: the package's ToastNotification in the
/// site's colors.
void showSiteToast(BuildContext context, String message) {
  final Palette p = Palette.of(context);
  ToastNotification.show(
    context: context,
    message: message,
    type: ToastType.success,
    position: ToastPosition.bottom,
    duration: const Duration(milliseconds: 2200),
    backgroundColor: p.ink,
    foregroundColor: p.bg,
    icon: Icons.check_rounded,
    borderRadius: kCorners,
    elevation: 0,
    showCloseButton: false,
    textStyle: AppFonts.text(TextStyle(fontSize: 15, color: p.bg)),
  );
}

class _CodeColors {
  const _CodeColors({
    required this.keyword,
    required this.type,
    required this.string,
    required this.number,
    required this.comment,
    required this.param,
    required this.punctuation,
  });

  factory _CodeColors.of(Palette p) => p.isDark
      ? const _CodeColors(
          keyword: Color(0xFFE8EEF0),
          type: Color(0xFF8FC1D4),
          string: Color(0xFFB7C99A),
          number: Color(0xFFE0A458),
          comment: Color(0xFF7E8D94),
          param: Color(0xFF9AA8AE),
          punctuation: Color(0xFF7E8D94),
        )
      : const _CodeColors(
          keyword: Color(0xFF1F3038),
          type: Color(0xFF2D5F75),
          string: Color(0xFF52702E),
          number: Color(0xFF9A5413),
          comment: Color(0xFF7E8D94),
          param: Color(0xFF5D6B72),
          punctuation: Color(0xFF7E8D94),
        );

  final Color keyword;
  final Color type;
  final Color string;
  final Color number;
  final Color comment;
  final Color param;
  final Color punctuation;
}

const Set<String> _keywords = {
  'abstract',
  'as',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'for',
  'if',
  'import',
  'in',
  'is',
  'late',
  'new',
  'null',
  'override',
  'required',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'while',
  'with',
  'yield',
  'show',
  'export',
};

final RegExp _token = RegExp(
  r"(//[^\n]*)" // 1 comment
  r"|('(?:[^'\\\n]|\\.)*'|"
  '"'
  r'(?:[^"\\\n]|\\.)*'
  '"'
  r")" // 2 string
  r"|(\b\d+(?:\.\d+)?\b|\b0x[0-9A-Fa-f]+\b)" // 3 number
  r"|(@?[A-Za-z_]\w*)" // 4 identifier
  r"|([(){}\[\],.;:<>=?!+\-*/&|]+)", // 5 punctuation
);

final RegExp _namedArg = RegExp(r'^\s*:(?!:)');

/// Splits Dart source into colored spans. A small lexer that is good enough
/// for snippets: comments, strings, numbers, keywords, types, named
/// arguments and punctuation.
List<TextSpan> _highlight(String code, _CodeColors c) {
  final List<TextSpan> spans = [];
  int last = 0;
  for (final RegExpMatch m in _token.allMatches(code)) {
    if (m.start > last) {
      spans.add(TextSpan(text: code.substring(last, m.start)));
    }
    final String text = m[0]!;
    Color? color;
    FontStyle? style;
    FontWeight? weight;
    if (m[1] != null) {
      color = c.comment;
      style = FontStyle.italic;
    } else if (m[2] != null) {
      color = c.string;
    } else if (m[3] != null) {
      color = c.number;
    } else if (m[4] != null) {
      final String rest = code.substring(m.end);
      if (_keywords.contains(text) || text.startsWith('@')) {
        color = c.keyword;
        weight = FontWeight.w600;
      } else if (_namedArg.hasMatch(rest) && text[0].toLowerCase() == text[0]) {
        color = c.param;
      } else if (text[0].toUpperCase() == text[0] && text[0] != '_') {
        color = c.type;
      }
    } else if (m[5] != null) {
      color = c.punctuation;
    }
    spans.add(
      TextSpan(
        text: text,
        style: TextStyle(color: color, fontStyle: style, fontWeight: weight),
      ),
    );
    last = m.end;
  }
  if (last < code.length) spans.add(TextSpan(text: code.substring(last)));
  return spans;
}
