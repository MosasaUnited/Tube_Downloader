import 'package:flutter/widgets.dart';

/// The direction of a TEXT FIELD that holds URLs (the URL bar, the
/// Multiple-links box): typed links keep their left-to-right order in an
/// Arabic layout, as in every browser's address bar.
const urlFieldDirection = TextDirection.ltr;

/// A URL, file path or other machine string shown inside a possibly-RTL
/// layout. It keeps its own left-to-right order (an Arabic base direction
/// would otherwise move "https://" and path separators around) while the
/// surrounding layout still mirrors. This file holds the ONLY sanctioned
/// TextDirection literals in lib/ (rtl-a11y skill; review-gate exempts it).
class LtrText extends StatelessWidget {
  const LtrText(this.text, {this.style, this.maxLines = 1, super.key});

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.ltr,
      // Align with the reading edge of the surrounding layout, not the LTR one.
      textAlign: Directionality.of(context) == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.left,
    );
  }
}
