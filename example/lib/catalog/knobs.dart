import 'package:flutter/material.dart';

/// A playground control. The values of all knobs of a page live in a
/// [Knobs] object that is passed to the demo and code builders.
abstract class Knob<T> {
  const Knob({
    required this.id,
    required this.label,
    required this.initial,
    this.help,
  });

  /// Key used to read the value, for example `knobs.pick('style')`.
  final String id;

  /// Label shown above the control.
  final String label;

  final T initial;

  /// Optional one line explanation shown under the control.
  final String? help;

  /// The Dart source for [value], used in code snippets.
  String codeFor(Object? value);
}

/// Picks one of a few [options]. Rendered as a segmented control for up to
/// four short options, and as a wrap of chips otherwise.
class SelectKnob<T> extends Knob<T> {
  const SelectKnob({
    required super.id,
    required super.label,
    required this.options,
    required super.initial,
    String Function(T value)? labelOf,
    String Function(T value)? codeOf,
    super.help,
  }) : _labelOf = labelOf,
       _codeOf = codeOf;

  /// A select over the values of an enum. [typeName] is the enum's class
  /// name, used to write `TypeName.value` in snippets (runtime type names
  /// are minified on the web, so it is passed explicitly).
  static SelectKnob<T> enumeration<T extends Enum>({
    required String id,
    required String label,
    required List<T> values,
    required T initial,
    required String typeName,
    String Function(T value)? labelOf,
    String? help,
  }) {
    return SelectKnob<T>(
      id: id,
      label: label,
      options: values,
      initial: initial,
      labelOf: labelOf ?? (T v) => _humanize(v.name),
      codeOf: (T v) => '$typeName.${v.name}',
      help: help,
    );
  }

  final List<T> options;
  final String Function(T value)? _labelOf;
  final String Function(T value)? _codeOf;

  String labelFor(Object? value) {
    final T v = value as T;
    return _labelOf?.call(v) ?? '$v';
  }

  @override
  String codeFor(Object? value) {
    final T v = value as T;
    return _codeOf?.call(v) ?? '$v';
  }
}

/// A continuous or stepped number.
class SliderKnob extends Knob<double> {
  const SliderKnob({
    required super.id,
    required super.label,
    required this.min,
    required this.max,
    required super.initial,
    this.divisions,
    String Function(double value)? format,
    String Function(double value)? codeOf,
    super.help,
  }) : _format = format,
       _codeOf = codeOf;

  /// A duration in milliseconds, shown as `600 ms` and written as
  /// `Duration(milliseconds: 600)`.
  const SliderKnob.duration({
    required super.id,
    required super.label,
    required this.min,
    required this.max,
    required super.initial,
    this.divisions,
    super.help,
  }) : _format = _formatMs,
       _codeOf = _codeMs;

  final double min;
  final double max;
  final int? divisions;
  final String Function(double value)? _format;
  final String Function(double value)? _codeOf;

  String display(double value) => _format?.call(value) ?? formatNumber(value);

  @override
  String codeFor(Object? value) =>
      _codeOf?.call(value! as double) ?? formatNumber(value! as double);

  static String _formatMs(double v) => '${v.round()} ms';
  static String _codeMs(double v) => 'Duration(milliseconds: ${v.round()})';
}

/// An on and off switch.
class ToggleKnob extends Knob<bool> {
  const ToggleKnob({
    required super.id,
    required super.label,
    required super.initial,
    super.help,
  });

  @override
  String codeFor(Object? value) => '$value';
}

/// A row of color swatches. A `null` swatch stands for the theme default.
class ColorKnob extends Knob<Color?> {
  const ColorKnob({
    required super.id,
    required super.label,
    required this.swatches,
    super.initial,
    super.help,
  });

  final List<Color?> swatches;

  @override
  String codeFor(Object? value) {
    if (value == null) return 'null';
    return colorCode(value as Color);
  }
}

/// A short free text, for example the text of a headline.
class TextKnob extends Knob<String> {
  const TextKnob({
    required super.id,
    required super.label,
    required super.initial,
    super.help,
  });

  @override
  String codeFor(Object? value) => quote(value! as String);
}

/// The current values of a page's knobs.
class Knobs extends ChangeNotifier {
  Knobs(List<Knob<Object?>> knobs)
    : _knobs = {for (final Knob<Object?> k in knobs) k.id: k},
      _values = {for (final Knob<Object?> k in knobs) k.id: k.initial};

  final Map<String, Knob<Object?>> _knobs;
  final Map<String, Object?> _values;

  Iterable<Knob<Object?>> get all => _knobs.values;

  /// The value of the knob [id].
  T pick<T>(String id) {
    assert(_values.containsKey(id), 'No knob with id "$id"');
    return _values[id] as T;
  }

  double number(String id) => pick<double>(id);
  bool flag(String id) => pick<bool>(id);
  Color? color(String id) => pick<Color?>(id);
  String text(String id) => pick<String>(id);

  /// Milliseconds knob as a [Duration].
  Duration ms(String id) => Duration(milliseconds: number(id).round());

  Object? valueOf(String id) => _values[id];

  void set(String id, Object? value) {
    if (_values[id] == value) return;
    _values[id] = value;
    notifyListeners();
  }

  bool isDefault(String id) => _values[id] == _knobs[id]!.initial;

  bool get allDefault => _knobs.keys.every(isDefault);

  void reset() {
    for (final Knob<Object?> k in _knobs.values) {
      _values[k.id] = k.initial;
    }
    notifyListeners();
  }

  /// The code for knob [id], or `null` when it still has its default value,
  /// so snippets only show what was changed.
  String? arg(String id) => isDefault(id) ? null : code(id);

  /// The code for knob [id], always.
  String code(String id) => _knobs[id]!.codeFor(_values[id]);
}

String _humanize(String name) {
  final String spaced = name.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])([A-Z])'),
    (m) => ' ${m[1]!.toLowerCase()}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Writes a number without a trailing `.0` noise beyond two decimals.
String formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(1);
  final String fixed = value.toStringAsFixed(2);
  return fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed;
}

String colorCode(Color c) {
  final int argb = c.toARGB32();
  return 'Color(0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()})';
}

String quote(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

/// Formats a constructor call with named arguments, one per line.
/// Arguments whose value is `null` are left out.
///
/// ```dart
/// dartCall('BorderBeam', {
///   'style': knobs.arg('style'),
///   'child': dartCall('Card', {'child': 'Text(...)'}),
/// })
/// ```
String dartCall(
  String name,
  Map<String, String?> args, {
  List<String> positional = const [],
}) {
  final List<String> parts = [
    ...positional,
    for (final MapEntry<String, String?> e in args.entries)
      if (e.value != null) '${e.key}: ${e.value}',
  ];
  if (parts.isEmpty) return '$name()';
  final String oneLine = '$name(${parts.join(', ')})';
  if (oneLine.length <= 60 && !oneLine.contains('\n') && parts.length <= 2) {
    return oneLine;
  }
  final StringBuffer b = StringBuffer('$name(\n');
  for (final String part in parts) {
    b.writeln('${indent(part)},');
  }
  b.write(')');
  return b.toString();
}

/// A list literal, one item per line.
String dartList(List<String> items, {String? type}) {
  final String prefix = type == null ? '' : '<$type>';
  if (items.isEmpty) return '$prefix[]';
  final String oneLine = '$prefix[${items.join(', ')}]';
  if (oneLine.length <= 60 && !oneLine.contains('\n')) return oneLine;
  final StringBuffer b = StringBuffer('$prefix[\n');
  for (final String item in items) {
    b.writeln('${indent(item)},');
  }
  b.write(']');
  return b.toString();
}

/// Indents every line of [code] by [by] spaces.
String indent(String code, [int by = 2]) {
  final String pad = ' ' * by;
  return code.split('\n').map((l) => l.isEmpty ? l : '$pad$l').join('\n');
}
