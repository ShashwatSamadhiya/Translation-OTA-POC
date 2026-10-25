# In-context editing

Editors change translations **inside the running app**: they tap a string on
screen, edit it, and see the result straight away. App users only see the
change after an editor publishes it.

The editor is the local package
[`../l10n_in_context`](../../l10n_in_context/README.md). It
knows nothing about Firebase: the app implements its two data-source
interfaces in
[`lib/src/features/l10n_editor/data/`](../lib/src/features/l10n_editor/data/),
and wires it up in [`app.dart`](../lib/src/app.dart).

Related docs:

- [EDIT_OVERLAY.md](EDIT_OVERLAY.md): how the overlay finds the string under
  a tap and draws highlights.
- [FIREBASE.md](FIREBASE.md): how the app talks to Firestore and Firebase
  Auth, the data model and the security rules.
- [FIREBASE_SETUP.md](FIREBASE_SETUP.md): how the Firebase project was set
  up, step by step.
- [HOW_IT_WORKS.md](HOW_IT_WORKS.md): OTA delivery, caching and the ICU
  formatter, which editing builds on.

---

## 1. The big picture

```
                        ┌──────────────── Firestore (one project) ────────────────┐
 Editor (edit mode) ──► │ translations_draft/{lang}  ──Publish──► translations_published/{lang} │
   live listener ◄───── │ translation_history/{id}                                │
                        └─────────────────────────────────────────────────────────┘
                                                                  │ one get() per fetch
                                                                  ▼
                                                       App users (any build)
```

| Who | Sees | How it gets text |
| --- | --- | --- |
| **App user** | Published text, else bundled ARB text | Reads `translations_published/{lang}` at start-up, on return to the app and on language change |
| **Signed-in editor** | Drafts layered over published text, over the app's OTA bundle | Live listeners on every draft and published document |

Editing never touches what app users see until someone presses
**Publish**.

## 2. Turning edit mode on

Edit mode exists only in builds whose env file contains:

```json
"L10N_EDIT_MODE": true
```

[`main.dart`](../lib/main.dart) turns it on only when that flag is set
**and** Firebase is configured:

```dart
final editMode = Env.l10nEditMode && firestore != null;
```

When it's on, `main.dart` creates the two data sources,
`FirebaseL10nAccessDataSource` and `FirestoreL10nTranslationDataSource`, and
passes them to `OtaPocApp`. [`app.dart`](../lib/src/app.dart) then wraps
`MaterialApp` in the package's `InContextEditor`:

```dart
InContextEditor(
  delegate: delegate,                 // AppLocalizationsOverrideDelegate with the OTA bundle
  accessDataSource: access,           // FirebaseL10nAccessDataSource
  translationDataSource: translations, // FirestoreL10nTranslationDataSource
  label: Env.firebaseProjectId,
  onRequestAccess: (context) => showEmailPasswordSignInDialog(
    context,
    signIn: access.signIn,
    subtitle: 'Firebase project: ${Env.firebaseProjectId}',
  ),
  onSignOut: access.signOut,
  builder: (context, l10n) => MaterialApp(
    localizationsDelegates: [l10n.delegate, ...],
    builder: l10n.overlay,
    ...
  ),
)
```

`InContextEditor` provides the editor's blocs, swaps in the editor's
delegate and installs `L10nEditOverlay` through `l10n.overlay`.
`Env.l10nEditMode` is a compile-time constant, so a build without the flag
contains none of the editor code.

## 3. Step by step

### 3.1 Sign-in

The package never signs anyone in. Its `EditorSessionBloc` only listens to
`L10nAccessDataSource.watchEditor()` and is `checking`, `noAccess` or
`editor`. The app's
[`FirebaseL10nAccessDataSource`](../lib/src/features/l10n_editor/data/firebase_l10n_access_data_source.dart)
implements it as Firebase Auth's `authStateChanges()`, filtered by the
`editors/{uid}` document:

1. On start-up, `authStateChanges()` reports whoever is still signed in from
   a previous session (on Web that arrives asynchronously, so the edit
   button stays disabled while `checking`).
2. Otherwise the overlay shows a round **edit button**. It calls
   `onRequestAccess`, which in this app opens the package's
   `showEmailPasswordSignInDialog` with `FirebaseL10nAccessDataSource.signIn`.
3. After Firebase Auth accepts the password, `signIn` checks that the
   document `editors/{uid}` exists. If it doesn't, the user is signed out
   again and the dialog shows "*email* is not an editor."
4. Once confirmed, `watchEditor()` emits an
   `EditorUser(id: uid, displayName: email)`, and the edit button turns into
   the editor toolbar.

The `editors` list is the permission system. A valid password alone is not
enough, and [`firestore.rules`](../firestore.rules) enforces the same check
on the server.

### 3.2 Drafts appear live

When `EditorSessionBloc` reports an editor, `InContextEditor` tells the
package's `TranslationsBloc` to subscribe to two collections through
[`FirestoreL10nTranslationDataSource`](../lib/src/features/l10n_editor/data/firestore_l10n_translation_data_source.dart):

```dart
watchDrafts()     // translations_draft/*
watchPublished()  // translations_published/*
```

`InContextEditor` then hands the app a copy of its delegate with the
editor's view on top of the app's own OTA messages:

```dart
delegate.copyWith(
  messages: {lang: {...?base[lang], ...snapshot.effectiveDraft(lang)}},
  tagKeys: true,
)
```

`effectiveDraft(lang)` is `{...published[lang], ...drafts[lang]}`. A key
nobody has edited shows its published text, and an edited key shows the
draft. Until the editor's data arrives, the app's OTA bundle (`base`) is
still shown. When any editor saves, Firestore pushes the new draft to every
signed-in editor and their screens re-render.

### 3.3 Every string gets an invisible tag

With `tagKeys: true`, every getter of the generated
[`AppLocalizationsOverride`](../lib/l10n/app_localizations_override.dart)
goes through the package's
[`L10nMessageResolver`](../../l10n_in_context/lib/src/presentation/l10n/l10n_message_resolver.dart),
which tags the result with the key's catalog index:

```dart
String _tag(int index, String value) =>
    tagKeys ? value + KeyTagCodec.encode(index) : value;
```

[`KeyTagCodec`](../../l10n_in_context/lib/src/core/l10n/l10n_key_tag.dart)
(package-internal; the only public API is `L10nKeyTag.strip`) appends:

```
U+2063 (start marker)  +  the key's index in appLocalizationsCatalog, in binary
                          0 → U+200C (ZWNJ)   1 → U+200D (ZWJ)
```

For example, `retry` is index 4 (`100` in binary), so `l10n.retry` becomes
`"Retry" + U+2063 + ZWJ + ZWNJ + ZWNJ`. The tag takes no space on screen,
but it stays in the text that Flutter renders. That's how a tap can be
traced back to its key.

- Bundled strings are tagged too, so even keys with no OTA text can be
  picked.
- Bundled-only keys (with date or number formats, `overridable: false`) are
  tagged through `bundledOnly` but marked read-only in the editor, because
  the app ignores OTA text for them.
- App users never get tags.

### 3.4 Picking a string

The editor taps **Pick** (cursor icon), then taps any text. The overlay
catches that tap so the button underneath doesn't fire, runs a hit test,
reads the tags from the text under the finger, and opens the edit dialog
for that key. [EDIT_OVERLAY.md](EDIT_OVERLAY.md) explains how.

**Highlight** outlines every tagged string on screen. It's useful for
spotting text that does *not* come from the ARB files.

### 3.5 The edit dialog

[`edit_key_dialog.dart`](../../l10n_in_context/lib/src/presentation/widgets/edit_key_dialog.dart)
shows, for the chosen key:

| Part | Source |
| --- | --- |
| Key name, description, placeholders with examples | `appLocalizationsCatalog` (generated from `app_en.arb`) |
| One tab per language, starting with the language on screen | `appLocalizationsCatalog.languages` |
| Text field with the current draft | `effectiveDraft(lang)`, else the bundled text |
| **Published** value with a **Use** button | `translations_published/{lang}` |
| **Bundled** value with a **Use** button | raw ARB text from `appLocalizationsCatalog` |
| Live preview | `IcuMessageFormatter` with the ARB example values; plurals shown for 0, 1, 2 and 5 |

A dot after a language (`HI •`) means that tab has unsaved changes. **Save**
writes every changed language.

### 3.6 Checks before saving

The `ValidateMessage` use case
([`validate_message.dart`](../../l10n_in_context/lib/src/domain/usecases/validate_message.dart))
runs on every keystroke. **Save** stays disabled until every changed
language passes:

| Check | Example it blocks |
| --- | --- |
| Not empty | `"  "` |
| ICU syntax parses | `{count, plural, =0{none}` (missing `}`) |
| No unknown placeholder | `{nmae} registered` |
| No missing placeholder | `Farmer registered` (dropped `{name}`) |
| Renders with the example values | `{name, plural, other{x}}` (plural on a text placeholder) |

These are the same rules the app applies at runtime. A message that would
make the app fall back to the bundled string can't be saved. A unit test
confirms that every bundled ARB message passes.

### 3.7 Saving

**Save** adds `DraftsSaveRequested` to `TranslationsBloc`. Its `SaveDraft`
use case validates again, then calls
`FirestoreL10nTranslationDataSource.saveDraft`, which writes **one batch**
per language:

1. A merge into `translations_draft/{lang}`, which changes only
   `messages.<key>`, `updatedAt` and `updatedBy`.
2. A new `translation_history` entry with the old and new value.

Because it's a merge, two editors working on different keys never overwrite
each other. If two editors save the *same* key in the same language, the
last save wins, and the history keeps both values. Languages are saved one
at a time, stopping at the first failure, which the dialog shows.

### 3.8 Key table, import and publish

The table icon opens
[`l10n_key_table_page.dart`](../../l10n_in_context/lib/src/presentation/pages/l10n_key_table_page.dart):

- **Every key in every language**, including keys that never appear on the
  current screen. Tap a row to open the same edit dialog.
- **Search** by key name or text.
- **Filters:**
  - *No OTA text*: some language has neither draft nor published text.
  - *Changed from bundled*: the draft differs from the ARB.
  - *Not published*: the draft differs from what users see.
- **Import bundled ARB:** copies the ARB text into the drafts for
  overridable keys that have no text yet (the `ImportBundled` use case). Use
  it once to seed an empty project.
- **Publish (n):** `n` is the number of unpublished key/language pairs (also
  the badge on the toolbar icon). Publishing:
  1. Shows a diff: old text crossed out, new text below.
  2. On confirm, the `PublishDrafts` use case writes the full draft of each
     changed language to `translations_published/{lang}`, plus a history
     entry, in one batch.

Each finished save, import or publish is reported as a `TranslationsOutcome`
on `TranslationsBloc`'s state, which the dialog, the key table and the
overlay turn into messages.

### 3.9 App users get the change

Nothing is pushed to app users. Their app reads `translations_published`
again on the next launch, the next return to the app, a language change or
a tap on **Fetch from Firestore**. The new text then replaces the cache, and
[`app.dart`](../lib/src/app.dart) builds a new
`AppLocalizationsOverrideDelegate` from it, which rebuilds the screens.

## 4. What the generator contributes

`fvm dart run l10n_in_context:generate`
([`generator.dart`](../../l10n_in_context/lib/src/generator/generator.dart))
writes one file,
[`lib/l10n/app_localizations_override.dart`](../lib/l10n/app_localizations_override.dart).
Editing depends on:

| Part | What editing uses from it |
| --- | --- |
| `AppLocalizationsOverride` | Every getter calls `L10nMessageResolver.resolve(index, key, fallback, args)` (or `bundledOnly(index, fallback)`), which adds the tag |
| `appLocalizationsCatalog` | An `L10nCatalog`: the languages, and per key its order (the tag index), description, placeholder names, types and examples, the raw bundled text in all four languages, and `overridable` |
| `AppLocalizationsOverrideDelegate` | Carries the catalog and the messages to `InContextEditor` |

After changing any ARB file, run:

```sh
fvm flutter gen-l10n && fvm dart run l10n_in_context:generate
```

A tag stores an index into the catalog, so it's only meaningful within one
build. That's fine, because tags are created and read by the same running
app.

## 5. Code map

The package follows clean architecture: data sources → repositories (which
return `Either` via `fpdart`) → use cases → blocs. Package paths are under
`../l10n_in_context/lib/src/`.

| Layer | File | Role |
| --- | --- | --- |
| Config (app) | [`env.dart`](../lib/src/core/config/env.dart) | `L10N_EDIT_MODE` and the Firebase options |
| Data (app) | [`firebase_l10n_access_data_source.dart`](../lib/src/features/l10n_editor/data/firebase_l10n_access_data_source.dart) | `L10nAccessDataSource`: `watchEditor()` from Firebase Auth and `editors/{uid}`, plus `signIn`/`signOut` for the UI |
| Data (app) | [`firestore_l10n_translation_data_source.dart`](../lib/src/features/l10n_editor/data/firestore_l10n_translation_data_source.dart) | `L10nTranslationDataSource`: Firestore reads and writes, with history entries |
| Generated (app) | [`app_localizations_override.dart`](../lib/l10n/app_localizations_override.dart) | `appLocalizationsCatalog`, `AppLocalizationsOverride`, `AppLocalizationsOverrideDelegate` |
| Core | [`l10n_key_tag.dart`](../../l10n_in_context/lib/src/core/l10n/l10n_key_tag.dart) | `KeyTagCodec` (internal encode/decode), `L10nKeyTag.strip` |
| Core | [`icu_message_formatter.dart`](../../l10n_in_context/lib/src/core/l10n/icu_message_formatter.dart) | Runtime ICU formatting |
| Data | [`l10n_access_data_source.dart`](../../l10n_in_context/lib/src/data/datasources/l10n_access_data_source.dart), [`l10n_translation_data_source.dart`](../../l10n_in_context/lib/src/data/datasources/l10n_translation_data_source.dart) | The interfaces the app implements |
| Data | [`repositories/`](../../l10n_in_context/lib/src/data/repositories/) | Turn data-source exceptions into `L10nFailure`s |
| Domain | [`l10n_catalog.dart`](../../l10n_in_context/lib/src/domain/entities/l10n_catalog.dart), [`editor_user.dart`](../../l10n_in_context/lib/src/domain/entities/editor_user.dart), [`translation_snapshot.dart`](../../l10n_in_context/lib/src/domain/entities/translation_snapshot.dart) | `L10nCatalog`, `L10nKeyInfo`, `L10nPlaceholder`, `EditorUser`, drafts and published |
| Domain | [`usecases/`](../../l10n_in_context/lib/src/domain/usecases/) | `ValidateMessage`, `SaveDraft`, `ImportBundled`, `PublishDrafts`, `WatchEditorAccess`, `WatchDrafts`, `WatchPublished` |
| State | [`bloc/`](../../l10n_in_context/lib/src/presentation/bloc/) | `EditorSessionBloc` (who may edit), `TranslationsBloc` (live drafts, save, import, publish), `EditorToolsCubit` (pick mode, highlight) |
| L10n | [`l10n_message_resolver.dart`](../../l10n_in_context/lib/src/presentation/l10n/l10n_message_resolver.dart), [`l10n_override_delegate.dart`](../../l10n_in_context/lib/src/presentation/l10n/l10n_override_delegate.dart) | Override-or-fallback per key, tagging, the delegate base class |
| UI | [`in_context_editor.dart`](../../l10n_in_context/lib/src/presentation/widgets/in_context_editor.dart) | Provides the blocs, layers drafts over the app's messages |
| UI | [`l10n_edit_overlay.dart`](../../l10n_in_context/lib/src/presentation/widgets/l10n_edit_overlay.dart) | Edit button, toolbar, pick mode, highlight |
| UI | [`tagged_text_finder.dart`](../../l10n_in_context/lib/src/presentation/widgets/tagged_text_finder.dart) | Finding tagged text in the render tree |
| UI | [`email_password_sign_in_dialog.dart`](../../l10n_in_context/lib/src/presentation/widgets/email_password_sign_in_dialog.dart), [`edit_key_dialog.dart`](../../l10n_in_context/lib/src/presentation/widgets/edit_key_dialog.dart), [`l10n_key_table_page.dart`](../../l10n_in_context/lib/src/presentation/pages/l10n_key_table_page.dart) | Dialogs and the key table |
| Wiring (app) | [`app.dart`](../lib/src/app.dart), [`main.dart`](../lib/main.dart) | Create the data sources, build the delegate from the OTA bundle, wrap `MaterialApp` in `InContextEditor` |

## 6. Tests

| Test | Covers |
| --- | --- |
| `../l10n_in_context/test/core/l10n_key_tag_test.dart` | Encoding round-trips, several tags in one text, stripping |
| `../l10n_in_context/test/presentation/l10n_override_delegate_test.dart` | Override or fallback per key, tags on override and bundled strings, none outside edit mode |
| `../l10n_in_context/test/domain/validate_message_test.dart` | Every rule in §3.6 |
| `../l10n_in_context/test/presentation/editor_session_bloc_test.dart`, `translations_bloc_test.dart` | The editor check, live drafts, save, import, publish, error handling, unsubscribing (with in-memory data sources) |
| `../l10n_in_context/test/presentation/in_context_editor_test.dart` | No access, no Edit button without `onRequestAccess`, an editor picking and editing a text |
| `../l10n_in_context/test/presentation/tagged_text_finder_test.dart` | Picking inside buttons, the `IgnorePointer` fallback, skipping hidden routes |
| `test/l10n/app_localizations_override_test.dart` | The app's generated file: OTA strings with fallback, tags in edit mode, the catalog, and every bundled message passing validation |

## 7. Known limits

- **Lost tags.** If code changes a localized string before showing it
  (`substring`, `toUpperCase()`, joining several strings, `split`), the tag
  is cut off or moved. Picking that text says "This text isn't from the ARB
  files". The key can still be edited from the key table.
- **Indic shaping.** ZWJ and ZWNJ change how Devanagari and Telugu render
  when they sit between letters. The tag starts with U+2063, so they should
  never touch a letter, but this hasn't been checked on a device.
- **Last save wins** for the same key and language.
- **Not included** compared with Tolgee: translation memory, machine
  translation, review states and comments.
