# Localization and the override generator

This page covers two things:

1. How Flutter localization works, from the ARB files to `AppLocalizations.of(context)`.
2. How `AppLocalizationsOverrideDelegate` hooks into it, and how
   `dart run l10n_in_context:generate` generates it, together with
   `AppLocalizationsOverride` and the key catalog, into
   `lib/l10n/app_localizations_override.dart`.

Firestore delivery, the cache and cubit, the ICU formatter and in-context
editing are covered in
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

### 2.1 `AppLocalizationsOverrideDelegate`

Generated in
[`app_localizations_override.dart`](../lib/l10n/app_localizations_override.dart).
It extends the package's
[`L10nOverrideDelegate<AppLocalizations>`](../../l10n_in_context/lib/src/presentation/l10n/l10n_override_delegate.dart),
which holds the logic; the generated subclass only fills in the
app-specific parts (`catalog`, `isSupported`, `lookupBundled`,
`createOverride`, `copyWith`).

It takes the generated delegate's place in [`app.dart`](../lib/src/app.dart),
built from the OTA cubit's bundle:

```dart
final delegate = AppLocalizationsOverrideDelegate(
  messages: {
    if (bundle != null) bundle.languageCode: bundle.messages,
  },
);
...
localizationsDelegates: [
  delegate,   // instead of AppLocalizations.delegate (l10n.delegate in edit mode)
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
],
```

| Member | Behaviour | Why |
| --- | --- | --- |
| `type` | `AppLocalizations`, from `extends L10nOverrideDelegate<AppLocalizations>` | Every `AppLocalizations.of(context)` now gets our object, so no screen changes. |
| `isSupported` | Passes the question to `AppLocalizations.delegate` | The supported languages always match the ARB files. |
| `load` | Looks up `messages` for the locale (exact match such as `pt_BR` first, then the language). Returns `AppLocalizationsOverride` if there are any (or always, when `tagKeys` is on in edit mode), otherwise the plain bundled class. Always a `SynchronousFuture`. | No blank first frame. An English bundle is never applied to Hindi while the user is switching language, because messages are keyed by language. |
| `shouldReload` | The `messages` maps differ (compared per language with `mapEquals`) or `tagKeys` changed | Identical strings don't trigger a rebuild. Any change does. |
| `copyWith` | A copy with other `messages` or `tagKeys` | `InContextEditor` uses it to layer the editor's drafts on top and turn tags on. |

### 2.2 What happens when an editor publishes a fix

```
1. App resumes or the user taps Fetch → OtaTranslationsCubit.refresh()
2. Repository reads translations_published/hi → new OtaTranslationBundle
3. Cubit emits a state with the new bundle
4. BlocBuilder in app.dart (buildWhen: locale or bundle changed)
   rebuilds MaterialApp with AppLocalizationsOverrideDelegate(messages: {hi: newMessages})
5. Localizations: shouldReload(old) == true → load(locale)
6. load returns a new AppLocalizationsOverride wrapping the new messages
7. InheritedWidget updates → widgets that read AppLocalizations rebuild
```

The `buildWhen` makes sure that refresh spinners and error messages don't
rebuild `MaterialApp`.

### 2.3 `AppLocalizationsOverride`

This is one more subclass of the generated abstract class, in the same
generated file. It wraps the bundled subclass for the current language and
overrides every member:

```dart
@override
String farmerRegistered(String name) => _messages.resolve(
  7,                                     // catalog index, for edit-mode tags
  'farmerRegistered',                    // key to look up in the OTA map
  () => _bundled.farmerRegistered(name), // per-key fallback
  {'name': name},                        // ICU arguments
);
```

`_messages` is the package's
[`L10nMessageResolver`](../../l10n_in_context/lib/src/presentation/l10n/l10n_message_resolver.dart).
`resolve` uses the OTA message if it exists, is not empty and is formatted
successfully by `IcuMessageFormatter`. Otherwise it uses the fallback.

Dart can't say "for any member, look up its name in a map", so every key
needs an explicit override. Because the parent class is abstract, a missing
override is a **compile error**. That's safe, but with 150+ keys it's tedious
to maintain by hand. The generator removes that work.

---

## Part 3: How the generator works

[`generator.dart`](../../l10n_in_context/lib/src/generator/generator.dart)
in the `l10n_in_context` package, run through its `bin/generate.dart`:

```sh
fvm flutter gen-l10n && fvm dart run l10n_in_context:generate   # write
fvm dart run l10n_in_context:generate --check                   # CI: exit 1 if stale
```

`--output=<path>` writes somewhere other than the default. The generator
itself uses only `dart:convert` and `dart:io`.

### Pipeline

```
l10n.yaml ──► L10nConfig.read ──► paths + class name
                                     │
lib/l10n/app_localizations.dart ──► parseMembers ──► [ Member(name, parameters) ]
                                     │
lib/l10n/app_en.arb ──────────────► formattedPlaceholders ──► keys that must stay bundled
lib/l10n/app_*.arb ───────────────► readBundledMessages ──► raw messages per language
                                     │
                  renderOverrideFile ──► Dart source (one file)
                                     │
                         _format ──► dart format (project language version)
                                     │
            write file  ◄────────────┴────────────►  --check: compare, exit 1 if different
```

### Step 1: Read `l10n.yaml` (`L10nConfig.read`)

The generator reads `arb-dir`, `template-arb-file`, `output-dir`,
`output-localization-file` and `output-class`. Missing values use
gen-l10n's defaults. `l10n.yaml` is flat `key: value`, so a line parser is
enough and no `yaml` package is needed. `synthetic-package: true` is
rejected. The output defaults to `<output-dir>/<file>_override.dart`, here
`lib/l10n/app_localizations_override.dart`, and every generated name is
derived from `output-class` (`AppLocalizationsOverride`,
`AppLocalizationsOverrideDelegate`, `appLocalizationsCatalog`).

### Step 2: Read signatures from the generated class (`parseMembers`)

The generator reads signatures from `app_localizations.dart`, **not from the
ARB**. That generated file is exactly what `AppLocalizationsOverride` has to
override, so the following are always correct:

- **Parameter order**: gen-l10n uses the order of `placeholders` in the
  metadata.
- **Inferred types**: a placeholder with no metadata becomes `Object`.
- **Plural and select arguments**: their types are decided by gen-l10n.

One regex inside the `abstract class AppLocalizations` body matches both
forms:

```
String get retry;                         → Member('retry', null)           // getter
String farmerRegistered(String name);     → Member('farmerRegistered', [String name])
```

A parameter it can't parse, such as a named or optional one, throws a clear
error instead of producing wrong code.

### Step 3: Find formatted placeholders (`formattedPlaceholders`)

The ARB file is read only for this step. A placeholder with a `format`
(`yMd`, `compact`, `decimalPattern`, …) or `isCustomDateFormat` is formatted
by gen-l10n with `intl` (`DateFormat` or `NumberFormat`). The runtime
formatter only calls `toString()`, so OTA text for these keys would look
different. Those keys are marked **bundled only**.

`bundledOnlyReason` also marks any parameter whose type isn't `String`,
`int`, `num`, `double` or `Object`, such as `DateTime`.

### Step 4: Write the override file (`renderOverrideFile`)

One file, `lib/l10n/app_localizations_override.dart`, with three parts in
this order.

**The key catalog.** `const appLocalizationsCatalog = L10nCatalog(languages:
[...], keys: [...])`. `languages` is the `@@locale` of every ARB file.
`keys` holds one `L10nKeyInfo` per member, in the same order: the name, the
description, the placeholders (`L10nPlaceholder` with name, type and
`example` from the template ARB), the raw message from every `app_*.arb`,
and `overridable` (false for bundled-only keys). The edit-mode tag stores a
key's index in this list. The editor uses the catalog for placeholder
checks, previews, **Use bundled** and **Import bundled ARB**. `L10nCatalog`,
`L10nKeyInfo` and `L10nPlaceholder` come from the package.

**`AppLocalizationsOverride`.** The constructor takes the bundled class and
an `L10nMessageResolver`, then there is one override per member, passing the
member's catalog index:

| Member | Generated code |
| --- | --- |
| Getter | `String get retry => _messages.resolve(4, 'retry', () => _bundled.retry);` |
| Method | `String x(String a, int b) => _messages.resolve(i, 'x', () => _bundled.x(a, b), {'a': a, 'b': b});` |
| Bundled only | `// Bundled only: <reason>.` then `String x(DateTime d) => _messages.bundledOnly(i, () => _bundled.x(d));` |

The resolver returns the value unchanged unless it was built with
`tagKeys: true` (in-context edit mode). Then it appends the key's invisible
tag. `resolve` tags both the OTA string and the bundled fallback, and
`bundledOnly` tags the bundled string, so every string on screen can be
picked.

**`AppLocalizationsOverrideDelegate`.** The `L10nOverrideDelegate` subclass
described in §2.1.

The import of `app_localizations.dart` is computed relative to the output
file (`_relativeImport`), following the project's relative-imports rule.
The package is imported as `package:l10n_in_context/l10n_in_context.dart`.

### Step 5: Format (`_format`)

The source is piped into `dart format --stdin-name=<output path>`, using the
same `dart` that runs the generator. `--stdin-name` makes the formatter use the
project's language version, so the result is byte-for-byte what
`dart format lib` produces. Without that, `--check` would report a stale file
after every format run.

### Step 6: Write or check

- **Default**: writes the file, then prints the key count and any
  bundled-only keys with the reason.
- **`--check`**: writes nothing. It exits with code 1 if the file is
  missing or different, so CI catches an ARB change that wasn't regenerated.

### Errors

| Situation | Result |
| --- | --- |
| Unknown option | Message and usage, exit code 64 |
| Not run from the project root (no `l10n.yaml`) | Message, exit code 2 |
| `synthetic-package: true` in `l10n.yaml` | Message, exit code 2 |
| `gen-l10n` hasn't run (generated file missing) | "cannot read <path>; run `flutter gen-l10n` from the app root first", exit code 2 |
| No `abstract class AppLocalizations` or no members | Message, exit code 2 |
| Unsupported parameter shape | Names the member, exit code 2 |
| An ARB file without `@@locale` | Names the file, exit code 2 |
| `dart format` fails | Shows the formatter's error, exit code 2 |

### Safety nets

1. **Forgot to run the generator:** the new abstract member has no override,
   so the build fails.
2. **Forgot in CI:** `--check` fails.
3. **Key typo:** impossible, because key strings are generated from the
   member names.
4. **Broken string in Firestore:** the formatter returns `null`, and the
   bundled text is shown for that key.

---

## Daily workflow

1. Add or edit the key in `lib/l10n/app_en.arb`, with placeholder metadata
   if needed, plus `app_hi.arb`, `app_mr.arb` and `app_te.arb`.
2. Run `fvm flutter gen-l10n && fvm dart run l10n_in_context:generate`.
3. Use it in code: `AppLocalizations.of(context).newKey`.
4. Ship the build. Editors can then change the key over the air from edit
   mode. **Import bundled ARB** in the key table seeds it in Firestore.
