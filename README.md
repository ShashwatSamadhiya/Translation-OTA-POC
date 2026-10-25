# OTA translations POC

This POC tests whether AquaSetu can update translations over the air without
shipping a new app build, and edit them **in context**, inside the running
app. Translations are stored in Firestore. It keeps `gen-l10n` and the
bundled ARB files as they are. An earlier version used Tolgee Cloud; what
we learned is kept [below](#what-we-learned-from-tolgee-cloud).

For the POC everything lives in **one Firebase project**: editors edit
drafts and publish them to the same project the app reads. The
multi-project plan (QA edits, promote to prod) is in
[docs/FIREBASE_IN_CONTEXT_PLAN.md](docs/FIREBASE_IN_CONTEXT_PLAN.md).

## How it works

| Doc | Covers |
| --- | --- |
| [HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md) | OTA delivery, caching, what ICU is and how a message is rendered |
| [LOCALIZATION_AND_GENERATOR.md](docs/LOCALIZATION_AND_GENERATOR.md) | Flutter localization, the override delegate and the generator |
| [IN_CONTEXT_EDITING.md](docs/IN_CONTEXT_EDITING.md) | The editing flow: sign-in, key tags, edit dialog, publish |
| [EDIT_OVERLAY.md](docs/EDIT_OVERLAY.md) | How `L10nEditOverlay` finds the string under a tap and draws highlights |
| [FIREBASE.md](docs/FIREBASE.md) | How the app connects to Firebase, the data model, security rules, limits |
| [FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) | Setting up the Firebase project, step by step, with troubleshooting |

```
Edit mode (editors) ──Save──► translations_draft/{lang} ──Publish──► translations_published/{lang}
                                                                          │ public read
FirestoreOtaDataSource ─► OtaTranslationRepository ─► OtaTranslationsCubit ◄┘
        cache ◄── OtaLocalDataSource (SharedPreferences)        │
                                                                ▼
                 AppLocalizationsOverrideDelegate ─► AppLocalizationsOverride
                 (generated; replaces AppLocalizations.delegate)
```

The in-context editor itself is a local package,
[`../l10n_in_context`](../l10n_in_context/README.md). The app
only supplies the Firebase side: who may edit
(`FirebaseL10nAccessDataSource`) and where drafts and published strings live
(`FirestoreL10nTranslationDataSource`), both in
`lib/src/features/l10n_editor/data/`.

- Screens still call `AppLocalizations.of(context).foo`, so no call site changes.
- For each key the app uses the published string if there is one. It falls
  back to the bundled ARB string when that string is missing, empty or
  malformed (for example a misspelled placeholder).
- At startup the app shows cached strings first, then reads Firestore once.
  It reads again when the app returns to the foreground. App users never
  keep a live listener open, so the cost is one read per fetch.
- `IcuMessageFormatter` (in the package) formats the parts of ICU that
  gen-l10n accepts at runtime: `{arg}`, `plural` (`=N`, CLDR categories, `#`)
  and `select`.
- New packages: `cloud_firestore` and `firebase_auth` (`firebase_core` is
  already in aqua_setu), plus the local `l10n_in_context` package, which
  brings `flutter_bloc`, `equatable` and `fpdart`.

## In-context editing

Builds with `"L10N_EDIT_MODE": true` in their env file show an edit button
in the bottom-right corner. After an editor signs in:

| Toolbar button | What it does |
| --- | --- |
| Pick (cursor icon) | The next tap selects a text on screen instead of pressing it, and opens the edit dialog for its key |
| Highlight | Outlines every string that comes from the ARB files |
| Keys (table icon) | Every key in every language, with search and filters. The badge counts unpublished changes. **Import bundled ARB** and **Publish** are here. |
| Sign out | Back to published strings |

- Editors see their drafts live on screen. App users only see what has been
  published.
- The edit dialog shows the draft, published and bundled text per language,
  and a preview with the ARB example values. It refuses to save broken ICU
  or placeholders that don't match the ARB.
- Each save, import and publish writes an entry to `translation_history`.
- Builds without `L10N_EDIT_MODE` compile the editor out entirely.

## Firebase setup (once)

Full step-by-step walkthrough with troubleshooting:
[docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md). In short:

1. Create a Firebase project, for example `aquasetu-l10n-poc`.
2. Turn on **Firestore** (Native mode, `asia-south1`) and
   **Authentication → Sign-in method → Email/Password**.
3. In Project settings, add the apps you'll run: **Web**, **Android**
   (`co.farmsetu.tolgee_poc`) and **iOS** (`co.farmsetu.tolgeePoc`). No
   `google-services.json` or plist is needed: the app passes its options
   from the env file.
4. Copy `env/example.json` to `env/web.json`, `env/ios.json` and
   `env/android.json`, and fill each one from that platform's app in
   Project settings (`env/*.json` is gitignored).
5. Deploy the security rules and the index exemption for `messages`:

   ```sh
   npm i -g firebase-tools && firebase login
   firebase deploy --only firestore --project <project-id>
   ```

6. Create each editor in **Authentication → Users**. Then, in Firestore,
   create a document `editors/<that user's UID>` (any field, for example
   `email`). Without that document, the editor is signed out straight after
   signing in.

## Run

```sh
fvm flutter gen-l10n && fvm dart run l10n_in_context:generate
fvm flutter run -d chrome --dart-define-from-file=env/web.json            # Web
fvm flutter run -d "iPhone 17 Pro" --dart-define-from-file=env/ios.json   # iOS simulator
fvm flutter run -d emulator --dart-define-from-file=env/android.json      # Android emulator
```

In VS Code, use the **Web · Chrome**, **iOS · simulator or iPhone** and
**Android · emulator or phone** launch configurations.

First run against an empty project: sign in, open **Keys**, tap **Import
bundled ARB**, then **Publish**. After that, edit any string with Pick,
publish, and check that a build without edit mode picks the change up on
resume or after tapping **Fetch from Firestore**.

Without the Firebase values in the env file, the app runs on the bundled
ARB strings and shows "Firebase is not configured".

## Adding or changing an ARB key

`lib/l10n/app_localizations_override.dart` is generated, so never edit it
by hand. It holds the key catalog the editor uses
(`appLocalizationsCatalog`), `AppLocalizationsOverride` and
`AppLocalizationsOverrideDelegate`. After changing any ARB file, run:

```sh
fvm flutter gen-l10n && fvm dart run l10n_in_context:generate
```

- The generator reads the signatures from the generated `AppLocalizations`
  class, so parameter names, types and order always match gen-l10n.
- A key whose placeholder has a `format` (a date or number format) or a
  `DateTime` type is generated as **bundled only**, and the generator lists
  it. The runtime formatter can't reproduce those formats.
- If you skip the generator, the build fails, because the new abstract member
  has no override. A key can never silently miss out on OTA updates.
- In CI, `fvm dart run l10n_in_context:generate --check` exits with code 1
  when the generated file is out of date.

## Checklist

| Question | Status |
| --- | --- |
| Do OTA strings render through `AppLocalizations` with no call site changes? | ✅ unit tests |
| Do placeholders, plurals and select work at runtime? | ✅ unit tests |
| Do empty or malformed strings fall back to the bundled ARB? | ✅ unit tests |
| Does cache-then-network work offline and on first launch? | ✅ cubit tests |
| Are late responses for a previous language dropped? | ✅ cubit tests |
| Does a tap find the right key, including inside buttons, and skip hidden routes? | ✅ widget tests |
| Are invalid ICU and mismatched placeholders blocked before saving? | ✅ unit tests, incl. every bundled message passing |
| Do the editor check, save, import and publish behave? | ✅ package bloc tests with in-memory data sources |
| Do the Web and Android builds compile with Firebase? | ✅ `flutter build web` / `apk --debug` |
| Does it work end to end against a real Firebase project? | ⏳ needs the setup above |
| Do the security rules reject non-editors? | ⏳ needs the setup above |
| How many aqua_setu strings lose their tag (`substring`, `toUpperCase`, joins)? | ⏳ try with aqua_setu screens |
| Does it work on iOS? | ⏳ manual run |

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

- Add the `l10n_in_context` package and run its generator; it reads
  `l10n.yaml`, so no paths need changing. The generator has been tested
  against aqua_setu's full ARB files (151 keys).
- Register the repository and cubits in GetIt. Load cached strings before
  `runApp` to avoid one frame of bundled text.
- Move to the multi-project plan in
  [docs/FIREBASE_IN_CONTEXT_PLAN.md](docs/FIREBASE_IN_CONTEXT_PLAN.md): edit
  on QA only, promote to prod with a script, and compile edit mode out of
  prod builds.
- Add App Check before production so only real app builds can read.
- Older builds: keys that an older build doesn't know are ignored. If a
  placeholder is renamed, older builds fall back to their bundled string
  for that key. That is safe, but the fix never reaches them, so treat
  placeholder names as a fixed contract.
