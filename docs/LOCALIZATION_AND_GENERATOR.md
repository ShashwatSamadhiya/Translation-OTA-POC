# Localization and the OTA generator

This page covers two things:

1. How Flutter localization works, from the ARB files to `AppLocalizations.of(context)`.
2. How `OtaLocalizationsDelegate` hooks into it, and how
   `tool/gen_ota_localizations.dart` generates `OtaAppLocalizations`.

The CDN, cache and cubit, and the ICU formatter, are covered in
[HOW_IT_WORKS.md](HOW_IT_WORKS.md).

---

## Part 1: How Flutter localization works

### 1.1 Build time: gen-l10n turns ARB files into Dart

[`l10n.yaml`](../l10n.yaml) tells `fvm flutter gen-l10n` where the ARB files
are and which one is the template:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb          # the source of truth for keys and placeholders
output-localization-file: app_localizations.dart
nullable-getter: false                 # AppLocalizations.of(context) is non-null
```

From this ARB entry:

```json
"farmerRegistered": "{name} registered",
"@farmerRegistered": { "placeholders": { "name": { "type": "String" } } }
```

gen-l10n generates three kinds of code in `lib/l10n/`:

```dart
// app_localizations.dart: one abstract member per key
abstract class AppLocalizations {
  String get retry;
  String farmerRegistered(String name);
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  static const List<Locale> supportedLocales = [Locale('en'), Locale('hi'), ...];
}

// app_localizations_hi.dart: one subclass per language with the bundled text
class AppLocalizationsHi extends AppLocalizations {
  @override String get retry => 'फिर से प्रयास करें';
  @override String farmerRegistered(String name) => '$name पंजीकृत हो गए';
}

// lookupAppLocalizations(locale): returns the right subclass for a locale
```

ICU messages are compiled into Dart here. For example, `pondCount` becomes an
`Intl.pluralLogic(...)` call. All of this text is fixed when the app is
built.

### 1.2 Runtime: the `Localizations` widget

`MaterialApp` takes a list of `localizationsDelegates` and creates a
`Localizations` widget from it. For the current locale, that widget:

1. Goes through the delegates **in order**. Each delegate has a `type` (the
   `T` in `LocalizationsDelegate<T>`) and an `isSupported(locale)` check.
2. Uses **only the first delegate for each type**. A later delegate with the
   same type is ignored.
3. Calls `load(locale)` on each delegate it uses, and stores the results by
   type:
   `{AppLocalizations: …, MaterialLocalizations: …, WidgetsLocalizations: …}`.
4. Shares that map through an `InheritedWidget`.

`AppLocalizations.of(context)` is just a lookup by type:

```dart
Localizations.of<AppLocalizations>(context, AppLocalizations)!
```

Screens never know which delegate produced the object. They only ask for
"the `AppLocalizations`". The OTA design depends on this.

### 1.3 When the locale or the delegates change

When `MaterialApp` rebuilds, `Localizations` compares the new delegate list
with the old one. It loads everything again when:

- the locale changed,
- the list has a different length or different delegate classes, or
- any delegate's `shouldReload(oldDelegate)` returns true.

After a load, the `InheritedWidget` updates and **only widgets that called
`AppLocalizations.of(context)` rebuild**.

If every `load` returns a `SynchronousFuture`, the new strings are used in the
same frame. With an ordinary `Future`, Flutter holds back the first frame on
startup, and on a reload it shows the old strings until the new ones arrive.

---

## Part 2: How OTA plugs in

### 2.1 `OtaLocalizationsDelegate`

[`ota_localizations_delegate.dart`](../lib/src/features/ota_translations/presentation/l10n/ota_localizations_delegate.dart)

It takes the generated delegate's place in [`app.dart`](../lib/src/app.dart):

```dart
localizationsDelegates: [
  OtaLocalizationsDelegate(state.bundle),   // instead of AppLocalizations.delegate
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
],
```

| Member | Behaviour | Why |
| --- | --- | --- |
| `type` | `AppLocalizations`, from `extends LocalizationsDelegate<AppLocalizations>` | Every `AppLocalizations.of(context)` now gets our object, so no screen changes. |
| `isSupported` | Passes the question to `AppLocalizations.delegate` | The supported languages always match the ARB files. |
| `load` | Returns `OtaAppLocalizations` if the bundle matches the locale's language, otherwise the plain bundled class. Always a `SynchronousFuture`. | No blank first frame. An English bundle is never applied to Hindi while the user is switching language. |
| `shouldReload` | `old.bundle != bundle`, a deep comparison through `Equatable` | Identical strings don't trigger a rebuild. Any change does. |

### 2.2 What happens when Tolgee publishes a fix

```
1. App resumes or the user taps Fetch → OtaTranslationsCubit.refresh()
2. Repository downloads hi.json → new OtaTranslationBundle
3. Cubit emits a state with the new bundle
4. BlocBuilder in app.dart (buildWhen: locale or bundle changed)
   rebuilds MaterialApp with OtaLocalizationsDelegate(newBundle)
5. Localizations: shouldReload(old) == true → load(locale)
6. load returns a new OtaAppLocalizations wrapping the new messages
7. InheritedWidget updates → widgets that read AppLocalizations rebuild
```

The `buildWhen` makes sure that refresh spinners and error messages don't
rebuild `MaterialApp`.

### 2.3 `OtaAppLocalizations`

This is one more subclass of the generated abstract class. It wraps the
bundled subclass for the current language and overrides every member:

```dart
@override
String farmerRegistered(String name) => _resolve(
  'farmerRegistered',                    // key to look up in the CDN map
  () => _bundled.farmerRegistered(name), // per-key fallback
  {'name': name},                        // ICU arguments
);
```

`_resolve` uses the OTA message if it exists, is not empty and is formatted
successfully by `IcuMessageFormatter`. Otherwise it uses the fallback.

Dart can't say "for any member, look up its name in a map", so every key
needs an explicit override. Because the parent class is abstract, a missing
override is a **compile error**. That's safe, but with 150+ keys it's tedious
to maintain by hand. The generator removes that work.

---

## Part 3: How the generator works

[`tool/gen_ota_localizations.dart`](../tool/gen_ota_localizations.dart)

```sh
fvm flutter gen-l10n && fvm dart run tool/gen_ota_localizations.dart   # write
fvm dart run tool/gen_ota_localizations.dart --check                   # CI: exit 1 if stale
```

It uses only `dart:convert` and `dart:io`, with no packages.

### Pipeline

```
l10n.yaml ──► _L10nConfig.read ──► paths + class name
                                     │
lib/l10n/app_localizations.dart ──► _parseMembers ──► [ _Member(name, parameters) ]
                                     │
lib/l10n/app_en.arb ──────────────► _formattedPlaceholders ──► keys that must stay bundled
                                     │
                         _render ──► Dart source
                                     │
                         _format ──► dart format (project language version)
                                     │
            write file  ◄────────────┴────────────►  --check: compare, exit 1 if different
```

### Step 1: Read `l10n.yaml` (`_L10nConfig.read`)

The script reads `arb-dir`, `template-arb-file`, `output-dir`,
`output-localization-file` and `output-class`. Missing values use
gen-l10n's defaults. `l10n.yaml` is flat `key: value`, so a line parser is
enough and no `yaml` package is needed.

### Step 2: Read signatures from the generated class (`_parseMembers`)

The script reads signatures from `app_localizations.dart`, **not from the
ARB**. That generated file is exactly what `OtaAppLocalizations` has to
override, so the following are always correct:

- **Parameter order**: gen-l10n uses the order of `placeholders` in the
  metadata.
- **Inferred types**: a placeholder with no metadata becomes `Object`.
- **Plural and select arguments**: their types are decided by gen-l10n.

One regex inside the `abstract class AppLocalizations` body matches both
forms:

```
String get retry;                         → _Member('retry', null)           // getter
String farmerRegistered(String name);     → _Member('farmerRegistered', [String name])
```

A parameter it can't parse, such as a named or optional one, throws a clear
error instead of producing wrong code.

### Step 3: Find formatted placeholders (`_formattedPlaceholders`)

The ARB file is read only for this step. A placeholder with a `format`
(`yMd`, `compact`, `decimalPattern`, …) or `isCustomDateFormat` is formatted
by gen-l10n with `intl` (`DateFormat` or `NumberFormat`). The runtime
formatter only calls `toString()`, so OTA text for these keys would look
different. Those keys are marked **bundled only**.

`_bundledOnlyReason` also marks any parameter whose type isn't `String`,
`int`, `num`, `double` or `Object`, such as `DateTime`.

### Step 4: Write the class (`_render`)

The output is the header, the constructor, `_resolve`, and then one override
per member:

| Member | Generated code |
| --- | --- |
| Getter | `String get retry => _resolve('retry', () => _bundled.retry);` |
| Method | `String x(String a, int b) => _resolve('x', () => _bundled.x(a, b), {'a': a, 'b': b});` |
| Bundled only | `// Bundled only: <reason>.` then `String x(DateTime d) => _bundled.x(d);` |

Import paths are computed relative to the output file (`_relativeImport`),
following the project's relative-imports rule.

### Step 5: Format (`_format`)

The source is piped into `dart format --stdin-name=<output path>`, using the
same `dart` that runs the script. `--stdin-name` makes the formatter use the
project's language version, so the result is byte-for-byte what
`dart format lib` produces. Without that, `--check` would report a stale file
after every format run.

### Step 6: Write or check

- **Default**: writes the file, then prints the key count and any
  bundled-only keys with the reason.
- **`--check`**: writes nothing. It exits with code 1 if the file is missing
  or different, so CI catches an ARB change that wasn't regenerated.

### Errors

| Situation | Result |
| --- | --- |
| Not run from the project root (no `l10n.yaml`) | Message, exit code 2 |
| `gen-l10n` hasn't run (generated file missing) | "run `fvm flutter gen-l10n` first", exit code 2 |
| No `abstract class AppLocalizations` or no members | Message, exit code 2 |
| Unsupported parameter shape | Names the member, exit code 2 |
| `dart format` fails | Shows the formatter's error, exit code 2 |

### Safety nets

1. **Forgot to run the script:** the new abstract member has no override,
   so the build fails.
2. **Forgot in CI:** `--check` fails.
3. **Key typo:** impossible, because key strings are generated from the
   member names.
4. **Broken string in Tolgee:** the formatter returns `null`, and the
   bundled text is shown for that key.

---

## Daily workflow

1. Add or edit the key in `lib/l10n/app_en.arb`, with placeholder metadata
   if needed, plus `app_hi.arb`, `app_mr.arb` and `app_te.arb`.
2. Run `fvm flutter gen-l10n && fvm dart run tool/gen_ota_localizations.dart`.
3. Use it in code: `AppLocalizations.of(context).newKey`.
4. Push the new key to Tolgee (import the ARB files) so translators can
   update it over the air later.
