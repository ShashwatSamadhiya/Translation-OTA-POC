# How the OTA translations POC works

This POC updates translations from Firestore without a new app release, and
lets editors change them in context, inside the running app.
Screens still call `AppLocalizations.of(context).retry`, just as aqua_setu does
today. The bundled ARB files stay in the app as the offline fallback.

For setup and run steps, see the [README](../README.md).

## 1. Architecture

```
Editors (edit mode) ─Publish─► Firestore translations_published/hi   (public read)
                                │
          FirestoreOtaDataSource│  one get() per session, resume and language change
                                ▼
          OtaTranslationRepository ──► caches it on the device (SharedPreferences)
                                ▼
          OtaTranslationsCubit   holds { locale, bundle, source, isRefreshing, failure }
                                ▼
          OtaLocalizationsDelegate  ──► OtaAppLocalizations
          (replaces AppLocalizations.delegate)
```

| Piece | What it does |
| --- | --- |
| [`ota_remote_data_source.dart`](../lib/src/features/ota_translations/data/datasources/ota_remote_data_source.dart) | Reads `translations_published/{lang}` once (no live listener, so app users cost one read per fetch) and returns its `messages` map. A missing document means no OTA strings yet. |
| [`ota_local_data_source.dart`](../lib/src/features/ota_translations/data/datasources/ota_local_data_source.dart) | Stores the last good download per language, so OTA strings survive a restart and work offline. A corrupt entry is deleted. |
| [`ota_translation_repository_impl.dart`](../lib/src/features/ota_translations/data/repositories/ota_translation_repository_impl.dart) | Maps errors to `Either<Failure, OtaTranslationBundle>`: not configured, network, or invalid payload. A failed cache write does not hide fresh strings. |
| [`ota_translations_cubit.dart`](../lib/src/features/ota_translations/presentation/cubit/ota_translations_cubit.dart) | Emits the cached copy first, then downloads the latest. It ignores a refresh while one is in progress, and drops a late response for a language the user has already switched away from. |
| [`ota_refresh_on_resume.dart`](../lib/src/features/ota_translations/presentation/widgets/ota_refresh_on_resume.dart) | Downloads again whenever the app returns to the foreground. |
| [`ota_localizations_delegate.dart`](../lib/src/features/ota_translations/presentation/l10n/ota_localizations_delegate.dart) | Takes the place of `AppLocalizations.delegate` and chooses between OTA and bundled strings. |
| [`ota_app_localizations.dart`](../lib/src/features/ota_translations/presentation/l10n/ota_app_localizations.dart) | Overrides each key so the OTA string is used first, with a per-key fallback to the bundled string. |
| [`icu_message_formatter.dart`](../lib/src/core/l10n/icu_message_formatter.dart) | Formats ICU messages at runtime. |

## 2. What ICU is

ICU MessageFormat is the standard syntax for translatable messages. Our ARB
files already use it, because it is what Flutter's `gen-l10n` reads. A
message can be more than a fixed string:

```text
"Retry"                                                         plain text
"{name} registered"                                             placeholder
"{count, plural, =0{No ponds} =1{1 pond} other{{count} ponds}}" plural
"{role, select, farmer{Farmer} other{Staff}}"                   select (choose by value)
```

Plurals are the hard part, because languages count differently. English has
`one` and `other`. In Hindi, both 0 and 1 are `one`. These rules come from
CLDR, the Unicode Consortium's shared database of language rules. Inside a
plural:

- `=0`, `=1` and so on are exact numbers.
- `zero`, `one`, `two`, `few`, `many` and `other` are CLDR categories.
- `#` stands for the number itself.
- `other` is required.

### Why the app needs its own formatter

`gen-l10n` normally turns ICU into Dart code at build time. For example,
`pondCount` becomes a call to `Intl.pluralLogic(count, zero: ..., one: ...,
other: ...)`. A string from the CDN arrives after the app is built, so no
generated code exists for it. The `intl` package can't parse ICU text at
runtime, so `IcuMessageFormatter` does that job.

## 3. How a string is rendered

As an example, take `l10n.pondCount(0)` in Hindi, using the real Tolgee
message:

```text
{count, plural, =0 {अभी कोई तालाब नहीं} =1 {1 तालाब} other {{count} तालाब}}
```

### Step 1: the delegate chooses the implementation

Flutter asks every `LocalizationsDelegate` to load the current locale.
`OtaLocalizationsDelegate` is registered in [`app.dart`](../lib/src/app.dart)
in place of `AppLocalizations.delegate`.

- If there is an OTA bundle for this language, it returns
  `OtaAppLocalizations`.
- Otherwise it returns the normal generated class.
- It returns a `SynchronousFuture`, so the first frame always has strings.
- When the cubit emits a new bundle, `shouldReload` returns true and Flutter
  rebuilds every widget that reads `AppLocalizations`. That is how the screen
  updates without a restart.

### Step 2: the override checks the OTA string first

```dart
@override
String pondCount(int count) =>
    _resolve('pondCount', () => _bundled.pondCount(count), {'count': count});
```

`_resolve` looks up the OTA message. If it is missing or empty, or the
formatter returns `null`, it uses the bundled ARB string **for that key only**.

`OtaAppLocalizations` extends the generated abstract class, so adding an ARB
key without an override fails to compile. The class is generated by
[`tool/gen_ota_localizations.dart`](../tool/gen_ota_localizations.dart):

1. The script reads every `String get key;` and `String key(Type a);`
   declaration from the gen-l10n output.
2. It writes one override per declaration: the key name, the fallback call and
   the arguments map.
3. A key whose placeholder declares a `format` (e.g. a date or `compact`) or a
   non-plain type such as `DateTime` becomes `=> _bundled.key(...)`, because
   the runtime formatter can't reproduce those formats.

### Step 3: the formatter parses the message

The parser reads the string one character at a time and builds a small tree:

```
Choice(name: count, plural) ─┬─ "=0"    → [Text "अभी कोई तालाब नहीं"]
                             ├─ "=1"    → [Text "1 तालाब"]
                             └─ "other" → [Argument count, Text " तालाब"]
```

Whitespace before `{` is skipped, which is why Tolgee's `=0 {…}` style works.
Any syntax error, such as unbalanced braces or a missing `other`, throws a
`FormatException`, and the formatter returns `null`.

### Step 4: the formatter picks a branch and renders it

1. The value is `count = 0`.
2. If an exact `=0` branch exists, it is used: "अभी कोई तालाब नहीं".
3. If there is no exact match, the formatter asks
   `Intl.pluralLogic(..., useExplicitNumberCases: false)` for the number's
   CLDR category in this locale, uses that branch, and falls back to `other`.
4. Placeholders are filled from the arguments. If a placeholder has no
   matching argument (for example a translator typed `{humidty}`), the
   formatter throws, returns `null`, and the bundled string is shown.

This is the main safety net: a mistake that slips past the editor's checks can never put broken
text on screen. At worst, that one key shows its bundled version.

### Limits

These match how `gen-l10n` behaves:

- Apostrophes are plain characters, as with gen-l10n's default
  `use-escaping: false`.
- `{n, number}` and date formats aren't supported. Our ARB files don't use
  them, and such a message falls back to the bundled string.

## 4. Failure behaviour

| Situation | What the user sees |
| --- | --- |
| First launch, offline | Bundled ARB strings |
| Offline with a cached bundle | Cached OTA strings |
| Firestore unreachable or times out (10 s) | Cached or bundled strings, and a refresh-failed message on the POC screen |
| A language was never published | Bundled strings for that language |
| `messages` is not a map | Same as unreachable (`InvalidPayloadFailure`) |
| One key missing, empty or malformed | Bundled string for that key, OTA strings for the rest |
| Firestore has keys this build doesn't know | Ignored |
| User switches language mid-download | The late response is dropped |

## 5. In-context editing

Editors change translations inside the running app, and publish them to
`translations_published`, which this delivery flow reads. See:

- [IN_CONTEXT_EDITING.md](IN_CONTEXT_EDITING.md): the whole editing flow.
- [EDIT_OVERLAY.md](EDIT_OVERLAY.md): how a tap on screen is traced back to
  its ARB key.
- [FIREBASE.md](FIREBASE.md): the Firestore data model, auth and security
  rules.
