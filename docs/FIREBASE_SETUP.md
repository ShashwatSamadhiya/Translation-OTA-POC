# Firebase setup

How the POC's Firebase project was set up, and how to repeat it for a new
project. For how the app uses Firebase once it's set up, see
[FIREBASE.md](FIREBASE.md).

| | Our POC project |
| --- | --- |
| Display name | OTA-Translation |
| Project ID | `ota-translation` |
| Plan | Spark (free) |
| Firestore | `(default)` database, Standard edition |
| Registered apps | Web, iOS, Android |

---

## Part 1: Firebase console

### Step 1: Create the project

1. In the [Firebase console](https://console.firebase.google.com), choose
   **Create a project**.
2. Name it, and note the **project ID** it generates. The app uses the ID
   (`ota-translation`), not the display name.
3. Google Analytics isn't needed.

### Step 2: Create the Firestore database

**Build → Firestore Database → Create database**:

| Setting | Choose | Why |
| --- | --- | --- |
| Edition | **Standard** | Enterprise is the MongoDB-compatible mode, which the Flutter `cloud_firestore` package doesn't use |
| Database ID | **`(default)`** | The app connects to the default database |
| Location | **`asia-south1` (Mumbai)** | Closest to our users. It can't be changed later. |
| Security rules | **Start in production mode** | Denies everything until our own rules are deployed (Step 6). Test mode would leave the database open to anyone for 30 days. |

### Step 3: Turn on email/password sign-in

**Build → Authentication → Get started → Sign-in method**:

1. Choose **Email/Password** (under *Native providers*).
2. Turn on **Email/Password**. Leave **Email link (passwordless sign-in)**
   off.
3. **Save**.

No other provider is needed.

### Step 4: Register the apps

**Project overview → + Add app**. Register only the platforms you'll run.

**Web** (done for the POC):

1. Choose the **Web** icon (`</>`), give it a nickname, and leave
   **Firebase Hosting** unticked.
2. Copy the values from the `firebaseConfig` snippet it shows into
   `env/web.json` (see Part 2). Ignore its npm and `<script>` instructions,
   which are for JavaScript apps.

**Android** (when needed):

- Package name: **`co.farmsetu.tolgee_poc`** (from
  `android/app/build.gradle.kts`).
- Download `google-services.json` only to read two values from it, for
  `env/android.json`: `client[0].api_key[0].current_key` (API key) and
  `client[0].client_info.mobilesdk_app_id` (App ID). Don't add the file to
  the project; the app passes its options from the env file instead.

**iOS** (when needed):

- Bundle ID: **`co.farmsetu.tolgeePoc`** (from the Xcode project).
- Download `GoogleService-Info.plist` only to read `API_KEY` and
  `GOOGLE_APP_ID` for `env/ios.json`. Don't add it to the project.

All registered apps share the project ID and sender ID. The **API key and
App ID differ per platform**. You can find them again later under
**Project settings → General → Your apps**.

### Step 5: Create the editor accounts

For each person who should edit translations:

1. **Authentication → Users → Add user**: enter their email and a password.
2. Copy the new user's **User UID**. It's case-sensitive, so copy and paste
   rather than retyping it.
3. **Firestore Database → Data → Start collection** (or open the existing
   `editors` collection):
   - Collection ID: **`editors`**
   - Document ID: **the User UID**
   - Field: `email` (string) = their email
4. **Save**.

Removing an editor: delete their `editors/{uid}` document. They lose access
immediately, even with a valid password. To lock them out of Firebase
entirely, also disable the user under **Authentication → Users**.

### Step 6: Deploy the security rules

Until this step, every read and write is denied, so the app shows "Could not
fetch translations" and editors can't save.

**Option A: the console** (no tools needed)

1. **Firestore Database → Rules**.
2. Replace everything with the contents of
   [`firestore.rules`](../firestore.rules).
3. **Publish**.

**Option B: the Firebase CLI** (also deploys the index exemptions)

```sh
npm i -g firebase-tools
firebase login
firebase deploy --only firestore --project ota-translation
```

This uses [`firebase.json`](../firebase.json), which points to
`firestore.rules` and
[`firestore.indexes.json`](../firestore.indexes.json). The index exemption
turns off indexing for the `messages` maps. The app works without it, but
it avoids creating an index entry for every translation key.

After changing `firestore.rules`, deploy again with either option.

---

## Part 2: The project's code

### Step 7: Env files, one per platform

Copy [`env/example.json`](../env/example.json) to `env/web.json`,
`env/ios.json` and `env/android.json`, and fill each one from that
platform's Firebase app:

| Env key | Web (`firebaseConfig`) | iOS (`GoogleService-Info.plist`) | Android (`google-services.json`) |
| --- | --- | --- | --- |
| `FIREBASE_API_KEY` | `apiKey` | `API_KEY` | `client[0].api_key[0].current_key` |
| `FIREBASE_PROJECT_ID` | `projectId` | `PROJECT_ID` | `project_info.project_id` |
| `FIREBASE_MESSAGING_SENDER_ID` | `messagingSenderId` | `GCM_SENDER_ID` | `project_info.project_number` |
| `FIREBASE_APP_ID` | `appId` | `GOOGLE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |

Other values (`authDomain`, `storageBucket`, `measurementId`, …) aren't
needed; the app derives the first two from the project ID.

```json
{
  "FIREBASE_API_KEY": "AIza…",
  "FIREBASE_PROJECT_ID": "ota-translation",
  "FIREBASE_MESSAGING_SENDER_ID": "998490357884",
  "FIREBASE_APP_ID": "1:998490357884:ios:…",
  "L10N_EDIT_MODE": true
}
```

- `env/*.json` is gitignored. Only `env/example.json` is committed.
- Leave out `L10N_EDIT_MODE` (or set it to `false`) for a build that behaves
  like a normal user's app: published text only, no edit button.
- A platform whose file has no App ID runs on bundled strings only.

### What was already done in the code

You don't need to repeat these; they're listed so the setup is complete.

| Change | Where |
| --- | --- |
| Added `firebase_core`, `cloud_firestore`, `firebase_auth`; removed `dio` | `pubspec.yaml` |
| Firebase options from the env file | `lib/src/core/config/env.dart` |
| `Firebase.initializeApp` and wiring | `lib/main.dart` |
| Firestore delivery | `lib/src/features/ota_translations/data/datasources/ota_remote_data_source.dart` |
| Editor auth and data (the Firebase side of the `l10n_in_context` package) | `lib/src/features/l10n_editor/data/` |
| In-context editor (UI, state, generator) | `../l10n_in_context/` |
| Security rules, index exemptions, CLI config | `firestore.rules`, `firestore.indexes.json`, `firebase.json` |
| Run configurations | `.vscode/launch.json`: one per platform, each with its own env file |

No native Firebase files were added. `google-services.json`, the iOS plist
and the Gradle Google Services plugin aren't used, because the options are
passed in code.

---

## Part 3: First run

### Step 8: Run the app

```sh
fvm flutter gen-l10n && fvm dart run l10n_in_context:generate

# Web
fvm flutter run -d chrome --dart-define-from-file=env/web.json

# iOS simulator
open -a Simulator
fvm flutter run -d "iPhone 17 Pro" --dart-define-from-file=env/ios.json

# Android emulator
fvm flutter emulators --launch Medium_Phone_API_36.1
fvm flutter run -d emulator --dart-define-from-file=env/android.json
```

In VS Code, pick **Web · Chrome**, **iOS · simulator or iPhone** or
**Android · emulator or phone** in Run and Debug. For iOS and Android, first
select a matching device in the status bar: the launch configuration
chooses the env file, and the selected device chooses where it runs.

### Step 9: Seed and publish

The database starts empty, so the app shows bundled text.

1. Tap the **edit button** (bottom right) and sign in with an editor
   account.
2. Open **Keys** (table icon) and tap **Import bundled ARB** (download
   icon). This copies every ARB string into the drafts.
3. Tap **Publish (n)** and confirm.

`translations_draft`, `translations_published` and `translation_history`
now appear in the Firestore console.

### Step 10: Check the full loop

1. Tap **Pick** (cursor icon), tap any text, change it and **Save draft**.
   It updates on screen straight away.
2. Open **Keys** and **Publish** the change.
3. Run a second copy without edit mode (remove `L10N_EDIT_MODE` from a copy
   of the env file), or sign out. Tap **Fetch from Firestore**: the
   published text appears.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| "Firebase is not configured" | That platform's env file lacks the API key, the project ID or the App ID | Fill in `env/<platform>.json`, and run with `--dart-define-from-file=env/<platform>.json` |
| Firebase errors on one platform only (invalid API key, app not found) | The app was started with another platform's env file | Use the matching launch configuration or env file |
| No edit button | `L10N_EDIT_MODE` isn't `true`, or Firebase isn't configured | Check the env file |
| "Could not fetch translations: … permission-denied" | Rules not deployed (production mode denies everything) | Step 6 |
| "*email* is not an editor." | No `editors/{uid}` document, or the document ID doesn't match the UID exactly | Step 5. Copy the UID again. |
| Sign-in says the password or user is invalid | Wrong credentials, or Email/Password isn't enabled | Step 3, or reset the password under Authentication → Users |
| Save fails with "Missing or insufficient permissions" | Rules out of date, or the editor document was removed | Deploy the rules again, or check `editors` |
| Edits show for the editor but not for users | Not published yet | **Keys → Publish** |
| Users still see old text after publishing | The app hasn't fetched since | Return to the app, or tap **Fetch from Firestore** |
| Changed an ARB file and the editor shows old keys | Generated files are stale | Run `fvm flutter gen-l10n && fvm dart run l10n_in_context:generate` |
