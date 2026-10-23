# How the app uses Firebase

The POC uses two Firebase products in **one project** (`ota-translation`):

| Product | Used for |
| --- | --- |
| **Cloud Firestore** | Storing drafts and published translations, the history log and the editor list |
| **Firebase Authentication** (email/password) | Signing editors in |

App users never sign in. They only read published translations, which are
public.

For how the project was created, see [FIREBASE_SETUP.md](FIREBASE_SETUP.md).
For the editing flow on top of this, see
[IN_CONTEXT_EDITING.md](IN_CONTEXT_EDITING.md).

---

## 1. Packages

| Package | Version | Why |
| --- | --- | --- |
| `firebase_core` | ^4.15.0 | Required by every Firebase package. Same major version as aqua_setu. |
| `cloud_firestore` | ^6.10.0 | Delivery, drafts, history |
| `firebase_auth` | ^6.7.0 | Editor sign-in |

`dio` was removed together with the Tolgee CDN client.

## 2. Connecting to the project

### 2.1 Options come from the env file

There is no `google-services.json`, `GoogleService-Info.plist` or generated
`firebase_options.dart`. [`env.dart`](../lib/src/core/config/env.dart) builds
`FirebaseOptions` from `--dart-define-from-file` values:

| Env key | `FirebaseOptions` field |
| --- | --- |
| `FIREBASE_API_KEY` | `apiKey` |
| `FIREBASE_PROJECT_ID` | `projectId`. `authDomain` and `storageBucket` are derived from it. |
| `FIREBASE_MESSAGING_SENDER_ID` | `messagingSenderId` |
| `FIREBASE_APP_ID_WEB` / `_ANDROID` / `_IOS` | `appId`, chosen for the running platform |

`Env.firebaseOptions` returns `null` when the API key, the project ID or the
current platform's app ID is missing.

Why this approach:

- The project **always compiles**, even without any Firebase files, which
  matters for tests and CI.
- A missing config isn't a crash: the app falls back to bundled ARB text.
- Switching projects means switching env files, which is how aqua_setu
  handles flavors.

The Firebase **Web API key is not a secret**: it only identifies the
project, and access is controlled by the security rules. `env/*.json` is
gitignored anyway, and only `env/example.json` is committed.

### 2.2 Start-up

[`main.dart`](../lib/main.dart):

```dart
final firebaseOptions = Env.firebaseOptions;
if (firebaseOptions != null) {
  await Firebase.initializeApp(options: firebaseOptions);
}
final firestore = firebaseOptions == null ? null : FirebaseFirestore.instance;

final repository = OtaTranslationRepositoryImpl(
  remote: firestore == null ? null : FirestoreOtaDataSource(firestore),
  local: OtaLocalDataSource(prefs),
);

final editMode = Env.l10nEditMode && firestore != null;
```

| Situation | Result |
| --- | --- |
| No Firebase config | `remote` is null. The repository returns `NotConfiguredFailure`, and the POC screen says "Firebase is not configured". Bundled strings only. |
| Firebase config, no `L10N_EDIT_MODE` | OTA delivery only. The editor isn't created and is tree-shaken out. |
| Both | Delivery plus an `L10nEditorCubit` built on `FirebaseL10nEditorDataSource(auth, firestore)` |

## 3. Data model

All collections live in the `(default)` database. The names are defined
once in
[`translations_firestore.dart`](../lib/src/core/firebase/translations_firestore.dart)
and must match [`firestore.rules`](../firestore.rules).

```
translations_published/{lang}     what every app build reads
translations_draft/{lang}         what editors edit
translation_history/{autoId}      append-only audit log
editors/{uid}                     who may edit (created by hand)
```

`{lang}` is one of `en`, `hi`, `mr`, `te`.

### `translations_published/{lang}`

```json
{
  "messages": {
    "retry": "फिर से कोशिश करें",
    "pondCount": "{count, plural, =0{अभी कोई तालाब नहीं} other{{count} तालाब}}"
  },
  "publishedAt": "<server timestamp>",
  "publishedBy": "<editor uid>"
}
```

### `translations_draft/{lang}`

```json
{
  "messages": { "retry": "दोबारा कोशिश करें" },
  "updatedAt": "<server timestamp>",
  "updatedBy": "<editor uid>"
}
```

A draft only needs the keys that were edited. Editors see
`{...published, ...draft}`.

### `translation_history/{autoId}`

| `type` | Fields |
| --- | --- |
| `edit` | `lang`, `key`, `oldValue`, `newValue` |
| `import` | `changedKeys: ["hi:retry", ...]` |
| `publish` | `changedKeys: ["hi:retry", ...]` |

Every entry also has `editorUid`, `editorEmail` and `at` (server timestamp).

### `editors/{uid}`

The document ID is the Firebase Auth UID. Its fields don't matter; we store
`email` for readability. Only its existence is checked.

### Message values

Messages are raw ICU strings, exactly as written in ARB files. `parseMessages`
in [`translations_firestore.dart`](../lib/src/core/firebase/translations_firestore.dart)
reads them:

- A missing document or `messages` field means no OTA strings yet, which
  gives an empty map.
- Non-string values are skipped, so one bad value drops only that key.
- A `messages` field that isn't a map throws `FormatException`, which
  becomes `InvalidPayloadFailure`.

## 4. App users: reading published text

[`ota_remote_data_source.dart`](../lib/src/features/ota_translations/data/datasources/ota_remote_data_source.dart):

```dart
final snapshot = await _firestore
    .collection('translations_published')
    .doc(languageCode)
    .get()
    .timeout(const Duration(seconds: 10));
return parseMessages(snapshot.data());
```

- **One `get()`, no listener.** A listener would cost one read per connected
  user for every publish. Reads happen at launch, on return to the app
  (`OtaRefreshOnResume`), on language change and when **Fetch from
  Firestore** is tapped.
- **No sign-in.** The security rules allow public reads of this collection.
- **Errors** are mapped in
  [`ota_translation_repository_impl.dart`](../lib/src/features/ota_translations/data/repositories/ota_translation_repository_impl.dart):

| Exception | Failure | User sees |
| --- | --- | --- |
| `FirebaseException` (offline, permission denied, …) | `NetworkFailure` | Cached or bundled text, plus the error on the POC screen |
| `TimeoutException` after 10 s | `NetworkFailure` | Same |
| `FormatException` | `InvalidPayloadFailure` | Same |

- **Caching:** a successful read is saved in SharedPreferences
  (`OtaLocalDataSource`), which is shown first on the next launch.
  Firestore's own offline cache (on by default on Android and iOS) is an
  extra layer on top: when offline, `get()` may return the cached document.

## 5. Editors: auth and live data

[`l10n_editor_data_source.dart`](../lib/src/features/l10n_editor/data/l10n_editor_data_source.dart)
defines `L10nEditorDataSource` (an interface, so the cubit can be tested
with a fake) and its Firebase implementation:

| Method | Firebase call |
| --- | --- |
| `restoreUser()` | `FirebaseAuth.authStateChanges().first`. On Web the saved session loads asynchronously, so `currentUser` would still be null at start-up. |
| `signIn(email, password)` | `signInWithEmailAndPassword` |
| `signOut()` | `FirebaseAuth.signOut` |
| `isEditor(uid)` | `get()` on `editors/{uid}`, checking `exists` |
| `watchDrafts()` | `snapshots()` on the whole `translations_draft` collection |
| `watchPublished()` | `snapshots()` on the whole `translations_published` collection |
| `saveDraft(...)` | Batch: `set(merge: true)` on `translations_draft/{lang}` with `messages: {key: value}`, plus `set` on a new history document |
| `importDrafts(...)` | Batch: one `set(merge: true)` per language, plus one history entry |
| `publish(...)` | Batch: `set` (full replace) on each changed `translations_published/{lang}`, plus one history entry |

Points worth knowing:

- **Merges protect concurrent edits.** `set(..., SetOptions(merge: true))`
  with `{'messages': {key: value}}` changes only `messages.<key>`. Two
  editors saving different keys never overwrite each other.
- **Batches are atomic.** The draft change and its history entry are written
  together or not at all. The same goes for a publish across languages.
- **Timestamps come from the server** (`FieldValue.serverTimestamp()`), so
  device clocks don't matter.
- **Live updates.** Both `snapshots()` streams push every change to every
  signed-in editor, which is how one editor's save appears on another's
  screen. The cubit cancels both subscriptions on sign-out and when it's
  closed.
- **Errors** from Firebase (`FirebaseException`, including
  `FirebaseAuthException`) are caught in the cubit and shown as text: inside
  the sign-in dialog, inside the edit dialog, or as a snackbar.

## 6. Security rules

[`firestore.rules`](../firestore.rules) is the real access control. The
app's own checks only make the UI friendlier.

```
isEditor() = signed in AND editors/{auth.uid} exists
```

| Collection | Read | Write |
| --- | --- | --- |
| `translations_published/{lang}` | **Anyone** | Editors, for supported languages only, and `publishedBy` must be their own UID |
| `translations_draft/{lang}` | Editors | **Create:** editors, supported languages, `updatedBy` is themselves. **Update:** the same, and only `messages`, `updatedAt` and `updatedBy` may change. **Delete:** nobody. |
| `translation_history/{id}` | Editors | **Create:** editors, `editorUid` is themselves. **Update and delete:** nobody. |
| `editors/{uid}` | Only that user, reading their own document | Nobody (managed in the console) |

Why public read is acceptable: the same strings already ship inside every
app build. Before production, add **App Check** so only genuine app builds
can read.

What the rules prevent:

- A signed-in user who isn't in `editors` can't read drafts or write
  anything.
- An editor can't impersonate another editor in `updatedBy`, `publishedBy`
  or `editorUid`.
- Nobody can rewrite or delete history, or edit the editor list from the
  app.
- Documents for unsupported languages can't be created.

## 7. Index exemptions

[`firestore.indexes.json`](../firestore.indexes.json) turns off indexing for
the `messages` field in both translation collections. By default Firestore
indexes every map entry, which means every translation key. We never query
by key, so those indexes would only cost storage and write time, and they
count toward Firestore's per-document index-entry limit.

## 8. Limits and cost

| | Value |
| --- | --- |
| Document size limit | 1 MiB per language. aqua_setu's 151 keys use about 20 KB, so the practical ceiling is about 3,000–5,000 keys (Indic text takes 3 bytes per character). |
| Reads per app user | 1 per fetch: launch, return to the app, language change. Typically 2–10 a day. |
| Reads per editor | About 8 at sign-in, then 1 for each document change |
| Writes | 2 per save, at most 5 per import or publish |
| Spark (free) plan | 50,000 reads and 20,000 writes a day, 10 GiB download a month |

Download traffic tends to run out first, because each read transfers the
whole ~20 KB document. When a quota runs out, reads fail and the app keeps
showing cached or bundled text. Check current prices on the Firestore
pricing page before production. For larger scale, serving published text as
files from Cloud Storage with `ETag` caching is the planned next step.

## 9. Moving beyond one project

[FIREBASE_IN_CONTEXT_PLAN.md](FIREBASE_IN_CONTEXT_PLAN.md) describes the
production layout: separate dev, QA and prod projects, editing only on QA,
and a `promote_translations.dart` script that copies QA's published text to
prod. The code above doesn't need to change for that; each flavor's env file
simply points at its own project.
