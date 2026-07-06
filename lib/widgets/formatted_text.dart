import 'package:flutter/material.dart';

/// Renders the couple's lightly-formatted description text (the same safe subset
/// the website supports) into styled widgets — no raw HTML.
///   `## Heading`, `**bold**`, `*italic*`, `- bullet`, blank line = spacing.
class FormattedText extends StatelessWidget {
  const FormattedText(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(
      context,
    ).style.copyWith(color: color, height: 1.5);

    final widgets = <Widget>[];
    final bullets = <String>[];

    void flushBullets() {
      for (final b in bullets) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: base),
                Expanded(child: Text.rich(_inline(b, base))),
              ],
            ),
          ),
        );
      }
      bullets.clear();
    }

    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.startsWith('## ')) {
        flushBullets();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              _strip(t.substring(3)),
              style: base.copyWith(
                fontSize: (base.fontSize ?? 14) + 4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      } else if (t.startsWith('- ')) {
        bullets.add(t.substring(2));
      } else if (t.isEmpty) {
        flushBullets();
        widgets.add(const SizedBox(height: 6));
      } else {
        flushBullets();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(_inline(line, base)),
          ),
        );
      }
    }
    flushBullets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Turns `**bold**` and `*italic*` into styled spans.
  TextSpan _inline(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    var last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: m.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: base, children: spans);
  }

  String _strip(String s) => s.replaceAll('**', '').replaceAll('*', '');
}
