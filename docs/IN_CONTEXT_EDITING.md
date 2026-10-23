# In-context editing

Editors change translations **inside the running app**: they tap a string on
screen, edit it, and see the result straight away. App users only see the
change after an editor publishes it.

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
| **Signed-in editor** | Drafts layered over published text | Live listeners on every draft and published document |

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

When it's on, `main.dart` also provides an `L10nEditorCubit`, and
[`app.dart`](../lib/src/app.dart) wraps the app in `L10nEditOverlay`.
`Env.l10nEditMode` is a compile-time constant, so a build without the flag
contains none of the editor code.

## 3. Step by step

### 3.1 Sign-in

1. On start-up, `L10nEditorCubit.start()` asks Firebase Auth whether someone
   is still signed in from a previous session.
2. Otherwise the overlay shows a round **edit button**. It opens the
   [sign-in dialog](../lib/src/features/l10n_editor/presentation/widgets/sign_in_dialog.dart)
   (email and password).
3. After Firebase Auth accepts the password, the cubit checks that the
   document `editors/{uid}` exists. If it doesn't, the user is signed out
   again with "*email* is not an editor."
4. Once confirmed, the edit button turns into the editor toolbar.

The `editors` list is the permission system. A valid password alone is not
enough, and [`firestore.rules`](../firestore.rules) enforces the same check
on the server.

### 3.2 Drafts appear live

After sign-in, the cubit subscribes to two collections:

```dart
_dataSource.watchDrafts()     // translations_draft/*
_dataSource.watchPublished()  // translations_published/*
```

[`app.dart`](../lib/src/app.dart) then builds the app with the editor's
view instead of the published bundle:

```dart
bundle: editor.isEditor
    ? OtaTranslationBundle(messages: editor.effectiveDraft(lang), ...)
    : state.bundle,
tagKeys: editor.isEditor,
```

`effectiveDraft(lang)` is `{...published[lang], ...drafts[lang]}`. A key
nobody has edited shows its published text, and an edited key shows the
draft. When any editor saves, Firestore pushes the new draft to every
signed-in editor and their screens re-render.

### 3.3 Every string gets an invisible tag

With `tagKeys: true`, the generated
[`OtaAppLocalizations`](../lib/src/features/ota_translations/presentation/l10n/ota_app_localizations.dart)
sends every string through `_tag`:

```dart
String _tag(String key, String value) =>
    _tagKeys ? L10nKeyTag.tag(key, value) : value;
```

[`L10nKeyTag`](../lib/src/core/l10n/l10n_key_tag.dart) appends:

```
U+2063 (start marker)  +  the key's index in l10nKeyCatalog, in binary
                          0 → U+200C (ZWNJ)   1 → U+200D (ZWJ)
```

For example, `retry` is index 4 (`100` in binary), so `l10n.retry` becomes
`"Retry" + U+2063 + ZWJ + ZWNJ + ZWNJ`. The tag takes no space on screen,
but it stays in the text that Flutter renders. That's how a tap can be
traced back to its key.

- Bundled strings are tagged too, so even keys with no OTA text can be
  picked.
- Bundled-only keys (with date or number formats) are tagged but marked
  read-only in the editor, because the app ignores OTA text for them.
- App users never get tags.

### 3.4 Picking a string

The editor taps **Pick** (cursor icon), then taps any text. The overlay
catches that tap so the button underneath doesn't fire, runs a hit test,
reads the tags from the text under the finger, and opens the edit dialog
for that key. [EDIT_OVERLAY.md](EDIT_OVERLAY.md) explains how.

**Highlight** outlines every tagged string on screen. It's useful for
spotting text that does *not* come from the ARB files.

### 3.5 The edit dialog

[`edit_key_dialog.dart`](../lib/src/features/l10n_editor/presentation/widgets/edit_key_dialog.dart)
shows, for the chosen key:

| Part | Source |
| --- | --- |
| Key name, description, placeholders with examples | `l10nKeyCatalog` (generated from `app_en.arb`) |
| One tab per language, starting with the language on screen | `AppLocalizations.supportedLocales` |
| Text field with the current draft | `effectiveDraft(lang)`, else the bundled text |
| **Published** value with a **Use** button | `translations_published/{lang}` |
| **Bundled** value with a **Use** button | raw ARB text from `l10nKeyCatalog` |
| Live preview | `IcuMessageFormatter` with the ARB example values; plurals shown for 0, 1, 2 and 5 |

A dot after a language (`HI •`) means that tab has unsaved changes. **Save**
writes every changed language.

### 3.6 Checks before saving

[`validate_message.dart`](../lib/src/features/l10n_editor/domain/validate_message.dart)
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

`L10nEditorCubit.saveDraft` validates again, then writes **one batch**:

1. A merge into `translations_draft/{lang}`, which changes only
   `messages.<key>`, `updatedAt` and `updatedBy`.
2. A new `translation_history` entry with the old and new value.

Because it's a merge, two editors working on different keys never overwrite
each other. If two editors save the *same* key in the same language, the
last save wins, and the history keeps both values.

### 3.8 Key table, import and publish

The table icon opens
[`l10n_key_table_page.dart`](../lib/src/features/l10n_editor/presentation/pages/l10n_key_table_page.dart):

- **Every key in every language**, including keys that never appear on the
  current screen. Tap a row to open the same edit dialog.
- **Search** by key name or text.
- **Filters:**
  - *No OTA text*: some language has neither draft nor published text.
  - *Changed from bundled*: the draft differs from the ARB.
  - *Not published*: the draft differs from what users see.
- **Import bundled ARB:** copies the ARB text into the drafts for keys that
  have no text yet. Use it once to seed an empty project.
- **Publish (n):** `n` is the number of unpublished key/language pairs (also
  the badge on the toolbar icon). Publishing:
  1. Shows a diff: old text crossed out, new text below.
  2. On confirm, writes the full draft of each changed language to
     `translations_published/{lang}`, plus a history entry, in one batch.

### 3.9 App users get the change

Nothing is pushed to app users. Their app reads `translations_published`
again on the next launch, the next return to the app, a language change or
a tap on **Fetch from Firestore**. The new text then replaces the cache, and
`OtaLocalizationsDelegate` rebuilds the screens.

## 4. What the generator contributes

[`tool/gen_ota_localizations.dart`](../tool/gen_ota_localizations.dart)
writes two files that editing depends on:

| File | What editing uses from it |
| --- | --- |
| `ota_app_localizations.dart` | The `_tag` hook on every string |
| `lib/src/core/l10n/l10n_key_catalog.dart` | Key order (the tag index), descriptions, placeholder names, types and examples, and the raw bundled text in all four languages |

After changing any ARB file, run:

```sh
fvm flutter gen-l10n && fvm dart run tool/gen_ota_localizations.dart
```

A tag stores an index into the catalog, so it's only meaningful within one
build. That's fine, because tags are created and read by the same running
app.

## 5. Code map

| Layer | File | Role |
| --- | --- | --- |
| Config | [`env.dart`](../lib/src/core/config/env.dart) | `L10N_EDIT_MODE` and the Firebase options |
| Core | [`l10n_key_tag.dart`](../lib/src/core/l10n/l10n_key_tag.dart) | Encode, decode and strip tags |
| Core | [`l10n_key_info.dart`](../lib/src/core/l10n/l10n_key_info.dart) | `L10nKeyInfo`, `L10nPlaceholder` |
| Core | [`l10n_key_catalog.dart`](../lib/src/core/l10n/l10n_key_catalog.dart) | Generated list of every key |
| Data | [`l10n_editor_data_source.dart`](../lib/src/features/l10n_editor/data/l10n_editor_data_source.dart) | Auth plus Firestore reads and writes |
| Domain | [`validate_message.dart`](../lib/src/features/l10n_editor/domain/validate_message.dart) | Checks before saving |
| State | [`l10n_editor_cubit.dart`](../lib/src/features/l10n_editor/presentation/cubit/l10n_editor_cubit.dart), [`l10n_editor_state.dart`](../lib/src/features/l10n_editor/presentation/cubit/l10n_editor_state.dart) | Sign-in, live drafts, save, import, publish |
| UI | [`l10n_edit_overlay.dart`](../lib/src/features/l10n_editor/presentation/widgets/l10n_edit_overlay.dart) | Edit button, toolbar, pick mode, highlight |
| UI | [`tagged_text_finder.dart`](../lib/src/features/l10n_editor/presentation/widgets/tagged_text_finder.dart) | Finding tagged text in the render tree |
| UI | [`sign_in_dialog.dart`](../lib/src/features/l10n_editor/presentation/widgets/sign_in_dialog.dart), [`edit_key_dialog.dart`](../lib/src/features/l10n_editor/presentation/widgets/edit_key_dialog.dart), [`l10n_key_table_page.dart`](../lib/src/features/l10n_editor/presentation/pages/l10n_key_table_page.dart) | Dialogs and the key table |
| Wiring | [`app.dart`](../lib/src/app.dart), [`main.dart`](../lib/main.dart) | Switch between drafts and published text, and tagging on or off |

## 6. Tests

| Test | Covers |
| --- | --- |
| `test/core/l10n/l10n_key_tag_test.dart` | Encoding round-trips, several tags in one text, stripping |
| `test/features/ota_translations/ota_app_localizations_test.dart` | Tags on OTA and bundled strings, none outside edit mode |
| `test/features/l10n_editor/validate_message_test.dart` | Every rule in §3.6, and every bundled message passes |
| `test/features/l10n_editor/l10n_editor_cubit_test.dart` | Session restore, the editor check, save, import, publish, error handling, sign-out (with a fake data source) |
| `test/features/l10n_editor/tagged_text_finder_test.dart` | Picking inside buttons, the `IgnorePointer` fallback, skipping hidden routes |

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
