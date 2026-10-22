import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/src/features/ota_translations/data/datasources/ota_remote_data_source.dart';

void main() {
  test('parses a flat export from a JSON string', () {
    expect(parseTolgeeJson('{"retry":"Try again"}'), {'retry': 'Try again'});
  });

  test('flattens nested exports with dots', () {
    expect(
      parseTolgeeJson({
        'home': {'title': 'Home'},
      }),
      {'home.title': 'Home'},
    );
  });

  test('skips non-string leaves instead of failing the bundle', () {
    expect(parseTolgeeJson({'retry': 'Retry', 'count': 3, 'list': []}), {
      'retry': 'Retry',
    });
  });

  test('throws FormatException for non-object bodies', () {
    expect(() => parseTolgeeJson('[]'), throwsFormatException);
    expect(() => parseTolgeeJson('<html>error</html>'), throwsFormatException);
    expect(() => parseTolgeeJson(null), throwsFormatException);
  });
}
