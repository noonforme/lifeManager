import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The owner's appearance choice. [system] follows the platform brightness
/// and high-contrast setting.
enum LifeOSAppearance { system, day, night, highContrast, millennium }

/// The four LifeOS areas, each with its own keycap colour.
enum LifeOSArea {
  work('Work', 'W'),
  finance('Finance', 'F'),
  tracking('Tracking', 'T'),
  knowledge('Knowledge', 'K');

  const LifeOSArea(this.label, this.letter);

  final String label;
  final String letter;
}

/// Fill and text colour of one area keycap.
@immutable
final class AreaKeyColors {
  const AreaKeyColors({required this.fill, required this.ink});

  final Color fill;
  final Color ink;
}

/// Colour tokens of one palette. Widgets take every colour from here; none
/// uses a literal colour.
@immutable
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
    required this.areaKeys,
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

  final Map<LifeOSArea, AreaKeyColors> areaKeys;

  static const _dayKeys = {
    LifeOSArea.work: AreaKeyColors(
      fill: Color(0xff3a6ea5),
      ink: Color(0xffffffff),
    ),
    LifeOSArea.finance: AreaKeyColors(
      fill: Color(0xffd9a400),
      ink: Color(0xff1d1d1b),
    ),
    LifeOSArea.tracking: AreaKeyColors(
      fill: Color(0xff3f7a2e),
      ink: Color(0xffffffff),
    ),
    LifeOSArea.knowledge: AreaKeyColors(
      fill: Color(0xff7b5ea7),
      ink: Color(0xffffffff),
    ),
  };

  /// The day area keys, which other light palettes share.
  static const dayAreaKeys = _dayKeys;

  static const _nightKeys = {
    LifeOSArea.work: AreaKeyColors(
      fill: Color(0xff6e9fd4),
      ink: Color(0xff161715),
    ),
    LifeOSArea.finance: AreaKeyColors(
      fill: Color(0xffe8b923),
      ink: Color(0xff161715),
    ),
    LifeOSArea.tracking: AreaKeyColors(
      fill: Color(0xff7cbf62),
      ink: Color(0xff161715),
    ),
    LifeOSArea.knowledge: AreaKeyColors(
      fill: Color(0xffa98bd2),
      ink: Color(0xff161715),
    ),
  };

  /// Office Machine day palette.
  static const day = LifeOSTokens(
    ground: Color(0xffcfd1cc),
    paper: Color(0xfff4f5f2),
    ink: Color(0xff1d1d1b),
    muted: Color(0xff60635e),
    rule: Color(0xffdcded9),
    band: Color(0xffebede8),
    chrome: Color(0xffe2e4df),
    chromeLine: Color(0xffa9aca5),
    head: Color(0xff2b2c2a),
    headInk: Color(0xfff4f5f2),
    signal: Color(0xffe8590c),
    actionFill: Color(0xffc2410c),
    actionInk: Color(0xffffffff),
    runInk: Color(0xffb03a0a),
    selWash: Color(0xfffde3d2),
    selInk: Color(0xff1d1d1b),
    negative: Color(0xffb8261b),
    positive: Color(0xff2a6f2d),
    focus: Color(0xff1d1d1b),
    areaKeys: _dayKeys,
  );

  /// Office Machine night palette.
  static const night = LifeOSTokens(
    ground: Color(0xff161715),
    paper: Color(0xff242523),
    ink: Color(0xffecebe6),
    muted: Color(0xffa3a49e),
    rule: Color(0xff383936),
    band: Color(0xff2b2c29),
    chrome: Color(0xff1d1e1c),
    chromeLine: Color(0xff454642),
    head: Color(0xff0f100e),
    headInk: Color(0xffecebe6),
    signal: Color(0xffff6a1a),
    actionFill: Color(0xffff6a1a),
    actionInk: Color(0xff161715),
    runInk: Color(0xffff8a4c),
    selWash: Color(0xff4a2b18),
    selInk: Color(0xffecebe6),
    negative: Color(0xffff7d70),
    positive: Color(0xff94d394),
    focus: Color(0xffecebe6),
    areaKeys: _nightKeys,
  );

  /// Office Machine high-contrast palette.
  static const highContrast = LifeOSTokens(
    ground: Color(0xffbfc1bc),
    paper: Color(0xffffffff),
    ink: Color(0xff000000),
    muted: Color(0xff3d3f3b),
    rule: Color(0xff7a7d77),
    band: Color(0xfff0f1ee),
    chrome: Color(0xffe2e4df),
    chromeLine: Color(0xff3d3f3b),
    head: Color(0xff000000),
    headInk: Color(0xffffffff),
    signal: Color(0xffa83600),
    actionFill: Color(0xffa83600),
    actionInk: Color(0xffffffff),
    runInk: Color(0xffa83600),
    selWash: Color(0xffffd9c2),
    selInk: Color(0xff000000),
    negative: Color(0xffa0150b),
    positive: Color(0xff1f5e22),
    focus: Color(0xff000000),
    areaKeys: _dayKeys,
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
