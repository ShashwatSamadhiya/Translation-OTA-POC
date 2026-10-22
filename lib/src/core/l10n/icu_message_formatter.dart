import 'package:intl/intl.dart';

/// Formats the subset of ICU MessageFormat that gen-l10n accepts in our ARB
/// files: plain text, `{arg}` placeholders, `{arg, plural, ...}` (with `=N`,
/// CLDR categories and `#`) and `{arg, select, ...}`.
///
/// Apostrophes are kept literally, matching gen-l10n's default
/// `use-escaping: false`.
///
/// Returns null when a message cannot be formatted safely (syntax error,
/// unsupported argument type, missing argument) so callers can fall back to
/// the bundled string instead of showing a broken one.
abstract final class IcuMessageFormatter {
  static String? format(
    String message, {
    required String locale,
    Map<String, Object> args = const {},
  }) {
    try {
      final nodes = _Parser(message).parse();
      return _Renderer(args: args, locale: locale).render(nodes, null);
    } on FormatException {
      return null;
    }
  }
}

sealed class _Node {
  const _Node();
}

final class _Text extends _Node {
  const _Text(this.value);
  final String value;
}

final class _Argument extends _Node {
  const _Argument(this.name);
  final String name;
}

/// `#` inside a plural branch: the plural value itself.
final class _PluralValue extends _Node {
  const _PluralValue();
}

final class _Choice extends _Node {
  const _Choice({
    required this.name,
    required this.isPlural,
    required this.branches,
  });

  final String name;
  final bool isPlural;
  final Map<String, List<_Node>> branches;
}

const String _otherBranch = 'other';

final class _Parser {
  _Parser(this._source);

  final String _source;
  int _index = 0;

  List<_Node> parse() => _parseNodes(insidePlural: false, nested: false);

  List<_Node> _parseNodes({required bool insidePlural, required bool nested}) {
    final nodes = <_Node>[];
    final text = StringBuffer();

    void flushText() {
      if (text.isEmpty) return;
      nodes.add(_Text(text.toString()));
      text.clear();
    }

    while (_index < _source.length) {
      final char = _source[_index];
      if (char == '}') {
        if (!nested) {
          throw FormatException('Unbalanced "}"', _source, _index);
        }
        break;
      }
      if (char == '{') {
        flushText();
        nodes.add(_parseArgument());
      } else if (char == '#' && insidePlural) {
        flushText();
        nodes.add(const _PluralValue());
        _index++;
      } else {
        text.write(char);
        _index++;
      }
    }
    if (nested && _index >= _source.length) {
      throw FormatException('Missing "}"', _source, _index);
    }
    flushText();
    return nodes;
  }

  _Node _parseArgument() {
    _expect('{');
    final name = _readToken();
    _skipWhitespace();
    if (_peek() == '}') {
      _index++;
      return _Argument(name);
    }
    _expect(',');
    final type = _readToken();
    if (type != 'plural' && type != 'select') {
      throw FormatException('Unsupported argument type "$type"', _source);
    }
    _skipWhitespace();
    _expect(',');

    final branches = <String, List<_Node>>{};
    while (true) {
      _skipWhitespace();
      if (_peek() == '}') {
        _index++;
        break;
      }
      final selector = _readToken();
      _skipWhitespace();
      _expect('{');
      branches[selector] = _parseNodes(
        insidePlural: type == 'plural',
        nested: true,
      );
      _expect('}');
    }
    if (!branches.containsKey(_otherBranch)) {
      throw FormatException('Missing "other" branch for "$name"', _source);
    }
    return _Choice(name: name, isPlural: type == 'plural', branches: branches);
  }

  /// Reads an identifier, CLDR category or `=N` selector.
  String _readToken() {
    _skipWhitespace();
    final start = _index;
    while (_index < _source.length &&
        !_isWhitespace(_source[_index]) &&
        !'{},'.contains(_source[_index])) {
      _index++;
    }
    if (start == _index) {
      throw FormatException('Expected a name', _source, _index);
    }
    return _source.substring(start, _index);
  }

  String? _peek() => _index < _source.length ? _source[_index] : null;

  void _expect(String char) {
    if (_peek() != char) {
      throw FormatException('Expected "$char"', _source, _index);
    }
    _index++;
  }

  void _skipWhitespace() {
    while (_index < _source.length && _isWhitespace(_source[_index])) {
      _index++;
    }
  }

  static bool _isWhitespace(String char) => char.trim().isEmpty;
}

final class _Renderer {
  const _Renderer({required this.args, required this.locale});

  final Map<String, Object> args;
  final String locale;

  String render(List<_Node> nodes, num? pluralValue) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      buffer.write(switch (node) {
        _Text(:final value) => value,
        _Argument(:final name) => _argument(name),
        _PluralValue() => pluralValue?.toString() ?? '#',
        _Choice() => _choice(node),
      });
    }
    return buffer.toString();
  }

  Object _argument(String name) {
    final value = args[name];
    if (value == null) {
      throw FormatException('Missing argument "$name"');
    }
    return value;
  }

  String _choice(_Choice choice) {
    final value = _argument(choice.name);
    if (!choice.isPlural) {
      final branch =
          choice.branches[value.toString()] ?? choice.branches[_otherBranch];
      // Non-null: the parser rejects choices without an "other" branch.
      return render(branch!, null);
    }
    if (value is! num) {
      throw FormatException('Plural argument "${choice.name}" is not a number');
    }
    final exact = choice.branches['=$value'];
    if (exact != null) return render(exact, value);

    // Exact `=N` cases are handled above, so ask intl for the pure CLDR
    // category (e.g. Hindi treats 0 as "one").
    final category = Intl.pluralLogic(
      value,
      locale: locale,
      zero: 'zero',
      one: 'one',
      two: 'two',
      few: 'few',
      many: 'many',
      other: _otherBranch,
      useExplicitNumberCases: false,
    );
    final branch = choice.branches[category] ?? choice.branches[_otherBranch];
    // Non-null: the parser rejects choices without an "other" branch.
    return render(branch!, value);
  }
}
