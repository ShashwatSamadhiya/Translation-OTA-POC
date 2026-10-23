# Plan: Firebase delivery and in-context editing

Status: **POC implemented with a single Firebase project** (drafts and
published strings in the same project, no promote script). See the
[README](../README.md#in-context-editing). The multi-project parts below
(§1, §3 prod rules, §7 promotion) are still a proposal.

This plan replaces Tolgee with Firebase for storing and delivering
translations, and adds an edit mode in the app for in-context editing.

## Decisions so far

| Topic | Choice |
| --- | --- |
| Storage and delivery | **Firestore** |
| Environments | **One Firebase project per flavor** (dev, qa, prod), as aqua_setu does today |
| Where editing happens | **QA only.** Prod is changed only by promoting from QA. Dev is a sandbox. |
| Dashboard | **The app itself in edit mode** (Web or a QA build), plus a key table screen |
| Editor sign-in | **Firebase Auth, email/password** accounts created per editor |

## What stays and what changes

| Piece | Status |
| --- | --- |
| `OtaAppLocalizations`, `OtaLocalizationsDelegate`, `IcuMessageFormatter`, the generator | Kept. The generator gets two small additions (§6). |
| `OtaLocalDataSource` (SharedPreferences cache) | Kept: it gives the first frame cached strings before Firestore starts. |
| `OtaTranslationsCubit`, repository | Changed: they read from Firestore and add a live stream for edit mode. |
| `OtaRemoteDataSource` (Tolgee CDN), `mock_cdn/`, `tool/serve_mock_cdn.py`, `env/tolgee.json` | **Deleted** once the Firestore source works (no dead code). The Tolgee findings stay in the README. |

---

## 1. How the environments relate

```
           ┌─────────── QA Firebase project ───────────┐
editors ──►│ translations_draft ──Publish──► translations_published │──┐
 (QA build │            (in-app button)                │  │ promote_translations.dart
  edit mode)└───────────────────────────────────────────┘  │   --from qa --to prod
                                                           ▼   (dry run → --apply)
           ┌─────────── Prod Firebase project ─────────┐
           │ translations_published  ◄── promote only  │──► prod app users
           │ translations_releases   (rollback copies) │──► pull_translations.dart → ARB files
           └───────────────────────────────────────────┘

           ┌─────────── Dev Firebase project ──────────┐
           │ same layout as QA: a sandbox, never promoted │
           │ refresh from QA with --from qa --to dev       │
           └───────────────────────────────────────────┘
```

| Flavor | Reads | Edit mode | Gets changes from |
| --- | --- | --- | --- |
| **dev** | its own `translations_published` | On, for developers to try things | Its own edits. `--from qa --to dev` resets it to QA. |
| **qa** | its own `translations_published` | On, for **the** editors | Editors → Publish |
| **prod** | its own `translations_published` | **Compiled out** | Promote from QA only |

Consequences:

- **No drift in prod.** Prod is never edited directly, so the text that
  reaches prod is exactly what QA tested.
- Dev may differ from QA. That's by design, and one command brings it back
  in line.
- `pull_translations.dart` always reads from **prod**, so the ARB files
  follow what users actually see.

## 2. Firestore data model (the same collections in every project)

```
translations_draft/{lang}          ← dev/qa only: what editors edit
  messages: { retry: "…", … }
  updatedAt, updatedBy

translations_published/{lang}      ← what the app reads in every flavor
  messages: { … }
  publishedAt, publishedBy
  source: "editor" | "promote:qa@<publishedAt>"   ← where the text came from

translation_history/{autoId}       ← audit log: edit | publish | promote | rollback
  type, lang, key, oldValue, newValue, editorUid, editorEmail, at,
  changedKeys (for publish/promote)

translations_releases/{autoId}     ← prod only: copy of the previous prod text, saved before each promote
  messages: { en: {…}, hi: {…}, mr: {…}, te: {…} }
  replacedAt, replacedBy

editors/{uid}                      ← dev/qa: who may edit (created in the console)
promoters/{uid}                    ← prod: who may promote (1–2 leads, created in the console)
```

Each project has its own Auth users. QA editors have accounts in the QA
project. Promoters have accounts in the prod project. A QA editor's password
can't change prod.

**Limits:** a document can hold 1 MiB, and 151 keys use about 20 KB. Turn off
indexing for the `messages` field, because each key would otherwise create
an index entry and we never query by key.

## 3. Security rules: two files

### `firestore.rules` (dev and qa projects)

```
function isEditor() {
  return request.auth != null
      && exists(/databases/$(database)/documents/editors/$(request.auth.uid));
}
function isSupportedLang(lang) { return lang in ['en', 'hi', 'mr', 'te']; }

match /translations_published/{lang} {
  allow read: if true;
  allow write: if isEditor() && isSupportedLang(lang);   // in-app Publish
}
match /translations_draft/{lang} {
  allow read: if isEditor();
  allow create: if isEditor() && isSupportedLang(lang);  // Import bundled ARB
  allow update: if isEditor() && isSupportedLang(lang)
    && request.resource.data.diff(resource.data).affectedKeys()
         .hasOnly(['messages', 'updatedAt', 'updatedBy'])
    && request.resource.data.updatedBy == request.auth.uid;
  allow delete: if false;
}
match /translation_history/{id} {
  allow read: if isEditor();
  allow create: if isEditor() && request.resource.data.editorUid == request.auth.uid;
  allow update, delete: if false;
}
match /editors/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;
  allow write: if false;
}
```

### `firestore.prod.rules` (prod project)

```
function isPromoter() {
  return request.auth != null
      && exists(/databases/$(database)/documents/promoters/$(request.auth.uid));
}

match /translations_published/{lang} {
  allow read: if true;
  allow write: if isPromoter();                // promote / rollback script only
}
match /translations_releases/{id} {
  allow read, create: if isPromoter();
  allow update, delete: if false;
}
match /translation_history/{id} {
  allow read: if isPromoter();
  allow create: if isPromoter() && request.resource.data.editorUid == request.auth.uid;
  allow update, delete: if false;
}
match /promoters/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;
  allow write: if false;
}
// No translations_draft in prod: nothing matches, so every access is denied.
```

Deploy each file to its own project with
`firebase deploy --only firestore:rules --project <alias>`.
`firebase.json` maps the prod alias to `firestore.prod.rules`. Public read is
fine, because the same strings already ship inside the app. For production,
add **App Check** so only real app builds can read.

## 4. Delivery in the app

### Choosing the project per flavor

- In aqua_setu, the per-flavor native config files already pick the project
  (`android/app/src/<flavor>/`, `ios/config/<flavor>/`). On Web, a
  `FirebaseOptions` per flavor is chosen from `env/<flavor>.json`.
- The POC has no native flavors, so it passes explicit options generated by
  `flutterfire configure` (one `firebase_options_<flavor>.dart` per project),
  chosen by a `FLAVOR` value in the env file. This works on Android, iOS and
  Web without setting up native flavors.

### App users

- They read `translations_published/{lang}` **once per session**: at startup,
  when the app returns to the foreground, and when the language changes.
- They do **not** keep a live listener open. Firestore charges one read per
  client every time the document changes. With 10,000 active users and 50
  edits a day, live listening would cost about 500,000 reads a day, against
  about 20,000 reads with one read per session.
- `FirestoreOtaDataSource.fetchPublished(lang)` replaces the Tolgee
  `fetch(lang)`. The rest of the flow (cache first, then network, per-key
  fallback) doesn't change.

### Editors (dev and qa edit mode)

- They keep a live listener on `translations_draft/{lang}`, so a saved edit
  appears straight away on every editor's screen.
- The cubit gets `watchDraft(lang)`, which returns a `Stream`. The cubit
  cancels the subscription when the language changes and when it closes.

### Offline

- Our SharedPreferences cache stays as the first source, because it works
  the same on every platform and loads synchronously.
- Firestore's own offline cache is extra. It is on by default on
  Android/iOS. On Web we leave it off for the POC.

## 5. Edit mode (the in-context dashboard): dev and qa only

### 5.1 Turning it on

- A compile-time flag `L10N_EDIT_MODE=true` is set in `env/dev.json` and
  `env/qa.json` only. All edit-mode code is behind
  `if (Env.l10nEditMode)`, so **prod builds leave it out entirely**.
- A floating **Edit** button opens the sign-in screen (email/password
  through `firebase_auth`). After sign-in the app checks that
  `editors/{uid}` exists. If it doesn't, it shows "not an editor" and signs
  out.
- A banner shows which environment is being edited ("Editing QA"), so nobody
  confuses dev with QA.

### 5.2 Tagging strings with their key

- In edit mode, `OtaAppLocalizations._resolve` appends an **invisible tag**,
  the same approach Tolgee uses. The tag is a start marker followed by the
  key's index in the key catalog (§6) written in binary as zero-width
  characters: ZWNJ `U+200C` = 0, ZWJ `U+200D` = 1.
- No tag is added outside edit mode.
- `L10nKeyTag.encode(index)` / `decode(text)` live in `lib/src/core/l10n/`
  and get unit tests.

### 5.3 Picking a string on screen

- `L10nEditOverlay` wraps the app in `MaterialApp.builder`.
- **Pick mode** is turned on with the Edit button. While it's on, taps are
  captured (so buttons don't fire). On Web, Alt+click works without pick
  mode.
- On a tap, the overlay runs a hit test, collects `RenderParagraph` and
  `RenderEditable` objects, reads their text with `toPlainText()` and decodes
  the tag.
  - One key: open the edit dialog.
  - Several keys: show a list to choose from.
  - No key: show "this text isn't from the ARB files".
- **Highlight toggle:** outlines every tagged paragraph.

### 5.4 Edit dialog

For the selected key, the dialog shows:

- The key name, its description and example values from the catalog.
- For each language: the **draft**, the **published** value and the
  **bundled** value, with the current language first.
- **Live preview** rendered with the catalog's example values through
  `IcuMessageFormatter`.
- **Checks before saving:** the ICU syntax must parse, and the placeholders
  must exactly match the catalog (no missing, extra or misspelled
  placeholders). An invalid message can't be saved.
- **Save:** one batch that updates `translations_draft/{lang}.messages.<key>`
  (a single-field update, so editors on other keys don't clash) and creates a
  history entry.
- **Revert to bundled / published:** fills in the text field. It still has
  to be saved.

### 5.5 Key table screen

- All catalog keys × 4 languages, with search.
- Filters: *missing*, *changed from bundled*, *not yet published*.
- Tapping a row opens the same edit dialog. This also covers keys that never
  show on a screen.
- **Publish** (to this environment): shows a diff, and on confirm copies the
  drafts to `translations_published` in one batch with a history entry.
- **Import bundled ARB:** fills any missing draft keys from the bundled
  strings. This seeds a new project from inside the app.

## 6. Generator additions (`tool/gen_ota_localizations.dart`)

1. **Key catalog:** emit `const List<L10nKeyInfo> l10nKeyCatalog` with each
   key's name, placeholder names and types, description and examples, from
   the template ARB. The tag, the placeholder check and the key table all use
   it.
2. **Tagging hook:** generated `_resolve` calls `_tag(key, value)`. That's a
   no-op in prod and appends the invisible tag in edit mode.

`--check` keeps covering both outputs.

## 7. Promotion between projects: `tool/promote_translations.dart`

```sh
fvm dart run tool/promote_translations.dart --from qa --to prod            # dry run: prints the diff
fvm dart run tool/promote_translations.dart --from qa --to prod --apply    # asks for the promoter's password, then writes
fvm dart run tool/promote_translations.dart --to prod --rollback           # restores the previous release
fvm dart run tool/promote_translations.dart --status                       # dev vs qa vs prod: number of keys that differ
fvm dart run tool/promote_translations.dart --from qa --to dev --apply     # reset the dev sandbox to QA
```

It uses `dart:io`, `dart:convert`, `dio` (already in aqua_setu) and the app's
own `IcuMessageFormatter` and key catalog. It needs no Firebase Admin SDK and
no service account.

1. **Configuration:** project IDs and Web API keys come from
   `env/<flavor>.json` (`FIREBASE_PROJECT_ID`, `FIREBASE_WEB_API_KEY`),
   which is already gitignored.
2. **Read the source:** `GET translations_published/{lang}` for the four
   languages through the Firestore REST API. Reads are public, so no
   sign-in is needed.
3. **Read the target and print a diff:** per language, the keys that are
   added, changed or removed, with old → new text. It also warns when the
   target contains keys the source doesn't have.
4. **Check the source:** every message must pass `IcuMessageFormatter` and
   the placeholder check against the catalog, otherwise the script refuses
   to promote. A broken string can't reach prod.
5. **`--apply`:**
   1. Asks for the promoter's email and password, with no echo and no
      storage.
   2. Signs in to the **target** project through the Firebase Auth REST API
      to get an ID token, so the security rules apply.
   3. Writes everything in **one atomic Firestore `:commit`**: a
      `translations_releases` copy of the current target, all four
      `translations_published` documents with
      `source: "promote:qa@<publishedAt>"`, and one history entry with the
      changed keys.
   4. Either everything is written or nothing is.
6. **`--rollback`:** reads the newest `translations_releases` entry and
   writes it back to `translations_published` in one commit, with a history
   entry.
7. **`--status`:** compares all three environments and lists the keys that
   differ. It can run in CI to warn when QA has unpromoted changes.

Exit codes: 0 = done or no differences, 1 = differences in a dry run or
`--status`, 2 = error (auth, network, invalid strings).

## 8. Pulling translations back into the repo

`tool/pull_translations.dart --from prod`:

- Reads prod `translations_published/{lang}` through REST, with public read.
- Writes `lib/l10n/app_<lang>.arb`. It keeps the `@key` metadata from the
  template, writes keys in template order, and prints a diff.
- Then run gen-l10n and the generator, and commit as usual.

## 9. Packages (need your approval)

| Package | Why | In aqua_setu |
| --- | --- | --- |
| `firebase_core` | Required by every Firebase package | ✅ already there |
| `cloud_firestore` | Delivery, drafts, history | ❌ new |
| `firebase_auth` | Editor sign-in | ❌ new |
| `firebase_app_check` | Production only: restrict reads to real app builds | ❌ new, later |

The scripts use `dio` (already there). For tests, Firestore is hidden behind
our own data-source interface and replaced with hand-written fakes, so
`fake_cloud_firestore` isn't needed.

## 10. What you need to set up

For the POC, **two projects are enough** to prove promotion: `qa` and
`prod`. Dev uses the same layout as QA and can be added later.

1. Create `aquasetu-l10n-poc-qa` and `aquasetu-l10n-poc-prod`.
2. In each, turn on **Firestore** (Native mode, `asia-south1`) and
   **Authentication → Email/Password**.
3. Install the CLIs: `npm i -g firebase-tools` and
   `dart pub global activate flutterfire_cli`.
4. In `tolgee_poc`, run `flutterfire configure` once per project, writing
   `lib/firebase_options_qa.dart` and `lib/firebase_options_prod.dart`
   (Android, iOS, Web). These are **gitignored**, as aqua_setu does.
5. In QA: create editor accounts and an `editors/{uid}` document for each.
   In prod: create 1–2 promoter accounts and a `promoters/{uid}` document
   for each.
6. Deploy the rules: `firestore.rules` → qa, `firestore.prod.rules` → prod.
7. Add `FIREBASE_PROJECT_ID` and `FIREBASE_WEB_API_KEY` to `env/qa.json`
   and `env/prod.json`.

## 11. Phases

These are rough estimates for one developer.

| Phase | Scope | Done when | Estimate |
| --- | --- | --- | --- |
| 0 | Firebase setup (§10): **you** | Both projects configured, rules deployed | — |
| 1 | Firestore delivery with a project per flavor, published read, swap out Tolgee | qa and prod builds each show their own project's strings on Android/iOS/Web, and the cache and fallback still work | 2 days |
| 2 | Edit-mode flag (dev/qa only), sign-in, editor check, environment banner, live draft listener | An editor signs in on QA, and a draft edit shows live | 1 day |
| 3 | **Spike:** generator catalog + tag, overlay hit test, pick mode, highlight | Tapping any string shows its key, and we've counted how many aqua_setu strings lose the tag | 1–2 days |
| 4 | Edit dialog: checks, preview, save + history | Edit → save → the screen updates, and invalid ICU is blocked | 2 days |
| 5 | Key table, filters, import bundled, Publish | Full edit → publish cycle on QA | 1.5 days |
| 6 | `promote_translations.dart`: dry run, apply, rollback, status | QA → prod promote and rollback work, and the prod app shows the promoted text | 1.5 days |
| 7 | `pull_translations.dart`, docs, tests | `pull --from prod` → `gen-l10n` gives up-to-date ARB files | 1 day |

That's about **10–11 days** in total. If phase 3 shows that too many strings
lose their tag, we stop there and fall back to the key table only.

## 12. Risks and open questions

- **Forgetting to promote:** QA is fixed but prod isn't. `--status` in CI, or
  run before each release, flags unpromoted keys.
- **Promoting the wrong direction:** the script refuses `--from prod`
  (except for `--status`). `--to prod` needs a prod promoter account, and a
  dry run is the default.
- **Dev drifts away from QA:** this is expected, because dev is a sandbox.
  `--from qa --to dev --apply` resets it.
- **Keys only in newer builds:** keys an older build doesn't know are
  ignored. A renamed placeholder makes older builds fall back to their
  bundled text for that key. Treat placeholder names as a fixed contract and
  change the key name instead.
- **Tags get lost** when code changes a string with `substring`,
  `toUpperCase()` or joining. Phase 3 measures how often.
- **Gestures clash:** long-press could collide with existing actions. That's
  why pick mode captures taps instead.
- **Concurrent edits:** the last save wins for the same key and language, and
  the history keeps both values.
- **Not included** compared with Tolgee: translation memory, machine
  translation, review states, comments.
- **Cost:** with one read per session, the free tier (50,000 reads a day per
  project) covers the POC. Re-estimate against aqua_setu's real number of
  daily users before production.
