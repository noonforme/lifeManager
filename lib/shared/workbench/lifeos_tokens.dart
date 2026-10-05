import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The four LifeOS areas, each with its own keycap colour.
enum LifeOSArea {
  work('Work'),
  finance('Finance'),
  tracking('Tracking'),
  knowledge('Knowledge');

  const LifeOSArea(this.label);

  final String label;
}

final class LifeOSTokens {
  const LifeOSTokens({
    required this.ground,
    required this.paper,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.band,
    required this.chrome,
    required this.chromeLine,
    required this.head,
    required this.headInk,
    required this.signal,
    required this.actionFill,
    required this.actionInk,
    required this.runInk,
    required this.selWash,
    required this.selInk,
    required this.negative,
    required this.positive,
    required this.focus,
  });

  /// Casing behind panes and tiles.
  final Color ground;

  /// Registers, tiles, inspector and tree.
  final Color paper;

  /// Primary text.
  final Color ink;

  /// Labels and secondary text.
  final Color muted;

  /// Row and cell separators.
  final Color rule;

  /// Alternate row band and column headers.
  final Color band;

  /// Menu bar, toolbar and tab strip.
  final Color chrome;

  /// Pane and control borders.
  final Color chromeLine;

  /// Tile headers, status line and the active segment.
  final Color head;

  /// Text on [head].
  final Color headInk;

  /// Indicators: running dot, budget bars, selection outline.
  final Color signal;

  /// Primary button fill.
  final Color actionFill;

  /// Text on [actionFill].
  final Color actionInk;

  /// Running-state text.
  final Color runInk;

  /// Selected row fill.
  final Color selWash;

  /// Text on [selWash].
  final Color selInk;

  /// Over budget, short paid and negative amounts.
  final Color negative;

  /// Under budget and positive amounts.
  final Color positive;

  /// Keyboard focus ring.
  final Color focus;

  /// The area keycap colours.

  /// The LifeOS palette: the 2001 office PC (Millennium shell spec 3.3).
  static const millennium = LifeOSTokens(
    ground: Color(0xffece9d8),
    paper: Color(0xffffffff),
    ink: Color(0xff000000),
    muted: Color(0xff555555),
    rule: Color(0xffecebe5),
    band: Color(0xfff1efe2),
    chrome: Color(0xffece9d8),
    chromeLine: Color(0xffc5c2b2),
    head: Color(0xff0046d5),
    headInk: Color(0xffffffff),
    signal: Color(0xffd9500b),
    actionFill: Color(0xffffffff),
    actionInk: Color(0xff000000),
    runInk: Color(0xffb83d0b),
    selWash: Color(0xff316ac5),
    selInk: Color(0xffffffff),
    negative: Color(0xffcc0000),
    positive: Color(0xff2a752d),
    focus: Color(0xff000000),
  );
}

/// WCAG relative luminance of [color].
double relativeLuminance(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colours, from 1 to 21.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
