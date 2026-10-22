import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tolgee_poc/src/features/ota_translations/data/datasources/ota_local_data_source.dart';
import 'package:tolgee_poc/src/features/ota_translations/domain/entities/ota_translation_bundle.dart';

void main() {
  test('round-trips a bundle', () async {
    SharedPreferences.setMockInitialValues({});
    final source = OtaLocalDataSource(await SharedPreferences.getInstance());
    final bundle = OtaTranslationBundle(
      languageCode: 'te',
      messages: const {'retry': 'మళ్ళీ'},
      fetchedAt: DateTime.utc(2026, 10, 22, 9),
    );

    await source.write(bundle);

    expect(await source.read('te'), bundle);
    expect(await source.read('hi'), isNull);
  });

  test('drops a corrupt entry', () async {
    SharedPreferences.setMockInitialValues({'ota_translations_hi': '{oops'});
    final prefs = await SharedPreferences.getInstance();
    final source = OtaLocalDataSource(prefs);

    expect(await source.read('hi'), isNull);
    expect(prefs.containsKey('ota_translations_hi'), isFalse);
  });
}
