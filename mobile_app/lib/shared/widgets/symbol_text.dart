// SymbolText: a Text that draws the design's symbols (★ ✿ ⌫ ← ...) itself.
//
// Phones don't all have these characters in their fonts (and Cairo has none
// of them), so each one is an SVG in assets/symbols/, drawn at the place and
// size the character would have: the texts can stay exactly as in the design.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The symbols, with their width (per 1000 of the font size).
enum AppSymbol {
  blossom('✿', 'blossom', 888),
  star('★', 'star', 833),
  smile('⌣', 'smile', 959),
  arrowLeft('←', 'arrow_left', 1000),
  arrowRight('→', 'arrow_right', 1000),
  backspace('⌫', 'backspace', 1281),
  diamond('◆', 'diamond', 855),
  play('▶', 'play', 861),
  dot('●', 'dot', 604),
  ring('○', 'ring', 600),
  bar1('▂', 'bar1', 1000),
  bar3('▃', 'bar3', 1000),
  bar5('▅', 'bar5', 1000),
  bar6('▆', 'bar6', 1000),
  bar7('▇', 'bar7', 1000),
  check('✓', 'check', 749),
  qr('▦', 'qr', 855);

  const AppSymbol(this.char, this.file, this.width);

  final String char;
  final String file;
  final int width;

  static final _byChar = {for (final s in values) s.char: s};
}

class SymbolText extends StatelessWidget {
  const SymbolText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.softWrap,
    this.symbolColor,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final bool? softWrap;

  /// The color of the symbols, when not the color of the text
  /// (e.g. the gold ★ of "بستاني ★").
  final Color? symbolColor;

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.textScalerOf(context).scale(style.fontSize!);
    // Only symbols and spaces ("● ● ● ○", the sound bars): laid out here,
    // like the browser does (Flutter would keep them left to right in Arabic).
    if (text.characters.every(
      (c) => c == ' ' || AppSymbol._byChar.containsKey(c),
    )) {
      return _symbolsOnly(fontSize);
    }
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    for (final char in text.characters) {
      final symbol = AppSymbol._byChar[char];
      if (symbol == null) {
        buffer.write(char);
        continue;
      }
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString()));
        buffer.clear();
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _Symbol(
            symbol,
            fontSize: fontSize,
            style: symbolColor == null
                ? style
                : style.copyWith(color: symbolColor),
          ),
        ),
      );
    }
    if (buffer.isNotEmpty) spans.add(TextSpan(text: buffer.toString()));
    return Text.rich(
      TextSpan(children: spans),
      style: style,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }

  // Cairo's height above and below the baseline (per font size).
  static const _ascent = 1.305;
  static const _descent = 0.57;

  /// The width of a space in Cairo (per font size).
  static const _space = 0.22;

  /// Only symbols and spaces: one row per line, wrapped like text, from the
  /// right in Arabic. Each line is as tall as a line of Cairo text.
  Widget _symbolsOnly(double fontSize) {
    final lineHeight = style.height ?? (_ascent + _descent);
    final baseline = _ascent - (_ascent + _descent - lineHeight) / 2;
    final letterSpacing = style.letterSpacing ?? 0;
    final symbols = [
      for (final char in text.characters)
        if (char != ' ') AppSymbol._byChar[char]!,
    ];
    return Wrap(
      alignment: switch (textAlign) {
        TextAlign.center => WrapAlignment.center,
        TextAlign.end || TextAlign.right => WrapAlignment.end,
        _ => WrapAlignment.start,
      },
      // A space (and its letter spacing) between 2 symbols.
      spacing: fontSize * _space + letterSpacing,
      children: [
        for (final symbol in symbols)
          SizedBox(
            height: fontSize * lineHeight,
            child: Padding(
              padding: EdgeInsets.only(top: fontSize * (baseline - 0.8)),
              child: _Symbol(symbol, fontSize: fontSize, style: style),
            ),
          ),
      ],
    );
  }
}

/// One symbol: as wide as the character, with its baseline at 80% of the
/// font size (like in the SVG files: 1000 units = the font size).
class _Symbol extends StatelessWidget {
  const _Symbol(this.symbol, {required this.fontSize, required this.style});

  final AppSymbol symbol;
  final double fontSize;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final glyphWidth = fontSize * symbol.width / 1000;
    // Like CSS letter-spacing: extra space after each character.
    final width = glyphWidth + (style.letterSpacing ?? 0);
    Widget svg(Color color) => SvgPicture.asset(
      'assets/symbols/${symbol.file}.svg',
      width: glyphWidth,
      height: fontSize * 1.1,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    // The text shadows of the style (e.g. the trees of the orchard drawing).
    Widget glyph = svg(
      style.color ?? DefaultTextStyle.of(context).style.color!,
    );
    final shadows = style.shadows ?? const [];
    if (shadows.isNotEmpty) {
      glyph = Stack(
        clipBehavior: Clip.none,
        children: [
          for (final s in shadows)
            Transform.translate(
              offset: s.offset,
              child: s.blurRadius == 0
                  ? svg(s.color)
                  : ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: s.blurSigma,
                        sigmaY: s.blurSigma,
                        tileMode: TileMode.decal,
                      ),
                      child: svg(s.color),
                    ),
            ),
          glyph,
        ],
      );
    }

    // Takes less height in the line than the drawing (which may go a bit
    // lower), so a symbol never makes the line taller than the text.
    return _SymbolBox(
      size: Size(width, fontSize * 0.9),
      baseline: fontSize * 0.8,
      // The drawing keeps its own width, on the left: like the browser, the
      // letter spacing goes on its right (in Arabic too).
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: glyphWidth,
        maxWidth: glyphWidth,
        maxHeight: fontSize * 1.1,
        child: glyph,
      ),
    );
  }
}

/// A box of a fixed size that tells the text where its baseline is.
class _SymbolBox extends SingleChildRenderObjectWidget {
  const _SymbolBox({
    required this.size,
    required this.baseline,
    required super.child,
  });

  final Size size;
  final double baseline;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSymbolBox(size, baseline);

  @override
  void updateRenderObject(BuildContext context, _RenderSymbolBox renderObject) {
    renderObject
      ..boxSize = size
      ..baseline = baseline;
  }
}

class _RenderSymbolBox extends RenderProxyBox {
  _RenderSymbolBox(this._boxSize, this._baseline);

  Size _boxSize;
  set boxSize(Size value) {
    if (value == _boxSize) return;
    _boxSize = value;
    markNeedsLayout();
  }

  double _baseline;
  set baseline(double value) {
    if (value == _baseline) return;
    _baseline = value;
    markNeedsLayout();
  }

  // The size and the baseline are known: no need to ask the drawing.
  @override
  void performLayout() {
    size = constraints.constrain(_boxSize);
    // The drawing always gets its own size, even if the line squeezes us.
    child?.layout(BoxConstraints.tight(_boxSize));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_boxSize);

  @override
  double? computeDryBaseline(
    BoxConstraints constraints,
    TextBaseline baseline,
  ) => _baseline;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _baseline;

  @override
  double computeMinIntrinsicWidth(double height) => _boxSize.width;
  @override
  double computeMaxIntrinsicWidth(double height) => _boxSize.width;
  @override
  double computeMinIntrinsicHeight(double width) => _boxSize.height;
  @override
  double computeMaxIntrinsicHeight(double width) => _boxSize.height;
}
