# Tolgee OTA POC

This POC tests whether AquaSetu can update translations over the air from
Tolgee Cloud without shipping a new app build. It keeps `gen-l10n` and the
bundled ARB files as they are.

## How it works

[docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) explains the architecture, what
ICU is, and how a message is parsed and rendered step by step.
[docs/LOCALIZATION_AND_GENERATOR.md](docs/LOCALIZATION_AND_GENERATOR.md)
explains how Flutter localization and the OTA delegate fit together, and how
the generator script works.

```
Tolgee Cloud ──(auto-publish)──► Content Delivery CDN: <link>/<lang>.json
                                          │  public, no API key
                                          ▼
OtaRemoteDataSource (Dio) ─► OtaTranslationRepository ─► OtaTranslationsCubit
            cache ◄── OtaLocalDataSource (SharedPreferences)    │
                                                                ▼
                         OtaLocalizationsDelegate ─► OtaAppLocalizations
                         (replaces AppLocalizations.delegate)
```

- Screens still call `AppLocalizations.of(context).foo`, so no call site changes.
- For each key the app uses the CDN string if there is one. It falls back to the
  bundled ARB string when the CDN string is missing, empty or malformed (for
  example a misspelled placeholder).
- At startup the app shows cached strings first, then fetches from the CDN. It
  also re-fetches when the app returns to the foreground.
- `IcuMessageFormatter` formats the parts of ICU that gen-l10n accepts at
  runtime: `{arg}`, `plural` (`=N`, CLDR categories, `#`) and `select`.
- No new packages. Everything used here is already in aqua_setu.

## Run with the mock CDN

The mock serves `mock_cdn/*.json` with CORS headers, the same way the Tolgee
CDN does.

```sh
python3 -I tool/serve_mock_cdn.py                                  # http://localhost:8787
fvm flutter gen-l10n && fvm dart run tool/gen_ota_localizations.dart
fvm flutter run -d chrome --dart-define-from-file=env/dev.json        # Web / iOS simulator
fvm flutter run -d emulator --dart-define-from-file=env/dev-android.json  # Android emulator (10.0.2.2)
```

Edit a file in `mock_cdn/`, then tap **Fetch from CDN** or send the app to the
background and back. Rows marked with a cloud icon are being served over the
air. The `en` mock file contains an empty string and a misspelled placeholder
on purpose, to show the per-key fallback.

## Adding or changing an ARB key

`OtaAppLocalizations` is generated, so never edit it by hand. After changing
any ARB file, run:

```sh
fvm flutter gen-l10n && fvm dart run tool/gen_ota_localizations.dart
```

- The script reads the signatures from the generated `AppLocalizations` class,
  so parameter names, types and order always match gen-l10n.
- A key whose placeholder has a `format` (a date or number format) or a
  `DateTime` type is generated as **bundled only**, and the script lists it.
  The runtime formatter can't reproduce those formats.
- If you skip the script, the build fails, because the new abstract member has
  no override. A key can never silently miss out on OTA updates.
- In CI, `fvm dart run tool/gen_ota_localizations.dart --check` exits with
  code 1 when the generated file is out of date.

## Run against Tolgee Cloud

1. In Tolgee Cloud, create a project with the languages en, hi, mr and te.
2. Import `lib/l10n/app_*.arb` into the project (Import → Flutter ARB).
3. Go to Developer settings → Content Delivery → New, and set:
   - Format: **JSON** (flat, with no structure delimiter)
   - Message format: **ICU**
   - **Publish automatically**: on
4. Copy the CDN link into `env/tolgee.json` as `{"TOLGEE_CDN_URL": "<link>"}`
   (`env/*.json` is gitignored).
5. Run with `--dart-define-from-file=env/tolgee.json`, edit a string in
   Tolgee, and time how long the change takes to reach the app.

## Checklist

| Question | Status |
| --- | --- |
| Do OTA strings render through `AppLocalizations` with no call site changes? | ✅ mock, Web |
| Do placeholders, plurals and select work at runtime? | ✅ unit tests |
| Do empty or malformed CDN strings fall back to the bundled ARB? | ✅ unit tests + mock |
| Does cache-then-network work offline and on first launch? | ✅ cubit tests |
| Are late responses for a previous language dropped? | ✅ cubit tests |
| Does the Web build reach the CDN? | ✅ Tolgee CDN sends CORS `*` |
| Do Tolgee's JSON export placeholders and plurals match our ARB syntax? | ✅ Tolgee adds spaces (`=0 {…}`), which the formatter handles |
| How long does a change take from Tolgee to the app? (docs say ≤ 15 min) | ⏳ needs Tolgee Cloud |
| Does it work on Android and iOS devices? | ⏳ manual run |

## What we learned from Tolgee Cloud

- Tolgee creates Indian languages with region tags (`hi-IN`) by default, and
  the CDN file names follow those tags. Rename the tags to `hi`, `mr` and `te`
  so the file names match the ARB locales.
- Renaming a tag does not trigger auto-publish. It also clears the language
  filter in the Content Delivery configuration, so after a rename, re-select
  the languages and press **Publish**.
- Each publish replaces the whole file set, so old files are removed.
- The CDN serves files as `application/octet-stream` with
  `Cache-Control: max-age=30`, and returns an XML 404 for a missing language.
  The app handles that 404 as a `NetworkFailure` and falls back to the bundled
  strings.

## If adopted in aqua_setu

- Copy `tool/gen_ota_localizations.dart` across and update its `_outputPath`.
  It has been tested against aqua_setu's full ARB files (151 keys).
- Register the repository and cubit in GetIt. Load cached strings before
  `runApp` to avoid one frame of bundled text.
- The CDN link is public, so it is not a secret, but it can still live in
  `env/<flavor>.json`. Use one Tolgee CDN configuration per flavor if needed
  (the free plan allows only one).
- Older builds and Tolgee edits: keys that an older build doesn't know are
  ignored. If a placeholder is renamed in Tolgee, older builds fall back to
  their bundled string for that key. That is safe, but the fix never reaches
  them, so treat placeholder names as a fixed contract.
