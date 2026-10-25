# How `L10nEditOverlay` works

[`l10n_edit_overlay.dart`](../../l10n_in_context/lib/src/presentation/widgets/l10n_edit_overlay.dart)
is the on-screen part of in-context editing: the edit button, the editor
toolbar, pick mode and the highlight outlines. The render-tree searches it
relies on are in
[`tagged_text_finder.dart`](../../l10n_in_context/lib/src/presentation/widgets/tagged_text_finder.dart).
Both live in the `l10n_in_context` package and are not exported; the app
only reaches the overlay through `InContextEditor`.

This page assumes you know that, in edit mode, every localized string ends
with an invisible key tag. [IN_CONTEXT_EDITING.md §3.3](IN_CONTEXT_EDITING.md#33-every-string-gets-an-invisible-tag)
explains the tag.

---

## 1. Where it sits in the widget tree

[`app.dart`](../lib/src/app.dart) installs it through `MaterialApp.builder`,
using the `overlay` that `InContextEditor` hands to its builder:

```dart
InContextEditor(
  ...
  builder: (context, l10n) => MaterialApp(
    localizationsDelegates: [l10n.delegate, ...],
    builder: l10n.overlay,  // (context, child) => L10nEditOverlay(child: child)
    ...
  ),
)
```

```
InContextEditor                                           ← provides EditorConfig and the three blocs
 └─ MaterialApp
     └─ Theme, ScaffoldMessenger, Localizations, MediaQuery   ← available to the overlay
         └─ L10nEditOverlay                                   ← builder
             └─ Overlay.wrap                                  ← the overlay's own Overlay
                 └─ Navigator (child)                         ← every route, dialog and page
```

Sitting **above the Navigator** has these consequences:

| Consequence | How the code handles it |
| --- | --- |
| It stays on screen across every route, so the toolbar is always visible | Nothing to do: that's the point |
| `showDialog(context)` and `Navigator.of(context)` don't work from the overlay's own `context` (there is no Navigator above it) | The overlay finds the app's Navigator itself: it walks down from its content to the first `NavigatorState`, which is the one `MaterialApp` builds. Dialogs and pages open through that Navigator's context. An app can pass `InContextEditor(navigatorKey:)` instead, but this app doesn't. |
| There is no `Overlay` above it, so `Tooltip` would throw | The overlay wraps itself in `Overlay.wrap`, so the toolbar's buttons have tooltips |
| `ScaffoldMessenger` *is* above it | Snackbars use `ScaffoldMessenger.maybeOf(context)` and appear on the current page's `Scaffold` |

The overlay is installed whenever edit mode is compiled in, with or without
access, because the Edit button for people without access lives in it too.

## 2. The layer stack

`build()` returns a `Stack` with `fit: StackFit.expand`, inside
`Overlay.wrap`. From bottom to top:

```
 4  Positioned (bottom right)  edit button, or the editor toolbar
 3  GestureDetector            pick layer: only in pick mode, catches the next tap
 2  IgnorePointer/CustomPaint  highlight outlines: only when Highlight is on
 1  KeyedSubtree(_contentKey)  the app itself (the Navigator)
```

- **Layer 1** has a `GlobalKey`, so the overlay can get the app's root
  `RenderBox` and search it. Searching from here means the overlay's own
  widgets are never searched.
- **Layer 2** is wrapped in `IgnorePointer`, so the outlines never block a
  tap.
- **Layer 3** sits above the app but below the toolbar, so in pick mode the
  toolbar stays tappable (to cancel pick mode).
- **Layer 4** is plain English text, never localized, so it carries no tags
  and can't be picked by mistake. It is left out entirely for people without
  access when `onRequestAccess` isn't set.

## 3. State it reacts to

`InContextEditor` provides three blocs above `MaterialApp`, and the overlay
listens to all of them (`MultiBlocListener`, then `watch`/`select` in its
builder):

| Bloc / state field | Effect |
| --- | --- |
| `EditorSessionBloc` `status` | `checking`: the edit button is disabled while the access data source gives its first answer. `noAccess`: the edit button. `editor`: the toolbar. |
| `EditorSessionBloc` `failure` | Shown as a snackbar |
| `EditorToolsCubit` `pickMode` | Adds or removes layer 3 |
| `EditorToolsCubit` `highlight` | Adds or removes layer 2, and starts or stops the ticker (§5) |
| `TranslationsBloc` `unpublishedCount` | Badge count on the key-table button |
| `TranslationsBloc` `outcome` | A failed import, publish or sync is shown as a snackbar. Save failures are shown inside the edit dialog instead. Sign-in errors are shown inside the sign-in dialog. |

## 4. Pick mode

### 4.1 Catching the tap

When `pickMode` is true, layer 3 is a full-screen
`GestureDetector(behavior: HitTestBehavior.opaque)` with a faint tint. The
opaque behaviour makes it win the tap, so the button or list tile
underneath **never fires**. That's why there's a separate pick mode instead
of, say, long-press, which would clash with the app's own gestures.

`onTapUp` calls `_pick(globalPosition)`, which first turns pick mode off
(`EditorToolsCubit.setPickMode(false)`), so each pick is one tap.

### 4.2 Finding the text under the finger: `keysAt`

```dart
List<String> keysAt(L10nCatalog catalog, RenderBox root, Offset globalPosition)
```

The catalog (`appLocalizationsCatalog`, reached through the delegate passed
to `InContextEditor`) is needed because a tag only stores a key's index in
the catalog, not its name.

**Step 1: a real hit test.**

```dart
final result = BoxHitTestResult();
root.hitTest(result, position: root.globalToLocal(globalPosition));
```

This is the same hit test Flutter runs for a real tap, only started from the
app's root, so it skips our pick layer. `result.path` lists every render
object under the point, deepest first. `RenderParagraph` (what `Text` and
`RichText` create) always counts itself as hit, so text inside buttons, list
tiles and app bars is included.

A hit test also respects what the user can actually see:

- A dialog's modal barrier stops the test, so text on the page behind a
  dialog isn't found.
- Routes hidden under the current page aren't tested.

**Step 2: read the text and decode its tags.**

```dart
String? _textOf(HitTestTarget target) => switch (target) {
  RenderParagraph(:final text) => text.toPlainText(),   // Text, RichText
  RenderEditable(:final text?) => text.toPlainText(),   // TextField contents
  _ => null,
};
```

`toPlainText()` keeps the zero-width tag characters. `keysIn(catalog, text)`
decodes them into catalog indexes (the package-internal `KeyTagCodec`) and
looks up each key name; indexes outside the catalog are ignored. One
paragraph can
contain several tags, for example `Text('${l10n.a} · ${l10n.b}')`, so all
of them are collected.

**Step 3: a fallback for text that can't be hit.** Text inside
`IgnorePointer` or `AbsorbPointer` (common in disabled controls) is never
hit. If step 1 found nothing, the overlay checks the bounds of every visible
tagged text (§5.1) for one that contains the tap point.

### 4.3 What happens next

| Keys found | Result |
| --- | --- |
| None | Snackbar: "This text isn't from the ARB files." |
| One | Opens `showEditKeyDialog` for it |
| Several | A "Which string?" list, then the edit dialog |

The edit dialog opens through the navigator's context, so it gets a normal
route with the blocs and `EditorConfig` still reachable (`InContextEditor`
provides them above `MaterialApp`).

## 5. Highlight

### 5.1 Finding every tagged text: `findTaggedTexts`

```dart
List<TaggedText> findTaggedTexts(L10nCatalog catalog, RenderObject root)
```

It walks the render tree from the app's root. For each laid-out
`RenderParagraph` or `RenderEditable` with at least one tag, it records:

```dart
TaggedText(
  MatrixUtils.transformRect(node.getTransformTo(root), Offset.zero & node.size),
  keys,
)
```

`getTransformTo(root)` includes every scroll offset, transform and
animation, so the rectangle is where the text really is on screen.

**Why it walks with `visitChildrenForSemantics`.** A plain `visitChildren`
would also visit **offstage** children. The Navigator keeps earlier routes
alive in its `Overlay`, so after pushing a page, the previous page's text
is still in the tree, sitting under the new page. `visitChildrenForSemantics`
is how the accessibility tree is built, and it skips exactly those offstage
routes (and `Offstage` widgets). A widget test checks that, after a push,
only the new page is highlighted.

The trade-off: text inside `ExcludeSemantics` is skipped too. That's rare
for real UI text.

### 5.2 Keeping the outlines in place

Outlines must follow scrolling, animations and route changes, and none of
those rebuild the overlay. So while Highlight is on, the overlay runs a
`Ticker`:

```
every frame → _updateHighlights()
              → findTaggedTexts(catalog, root)
              → setState only if the rectangles changed
```

The ticker is started and stopped from the `EditorSessionBloc` and
`EditorToolsCubit` listeners (`_syncHighlight`), and disposed with the
widget. When nothing moves, the rectangles stay the
same and there's no extra rebuild. Walking the tree each frame is cheap at
this size, and it only happens for a signed-in editor with Highlight on.

### 5.3 Painting

`_HighlightPainter` draws a 1.5 px rounded outline, inflated by 2 px, around
each rectangle, in the theme's `tertiary` colour. It repaints only when the
list of rectangles changes.

## 6. Toolbar and edit button

| State | Shown in the bottom-right corner |
| --- | --- |
| No access | Small FAB (`Icons.edit_note`) that calls `InContextEditor.onRequestAccess` with the Navigator's context. In this app that opens `showEmailPasswordSignInDialog` (see [`app.dart`](../lib/src/app.dart)). Without `onRequestAccess` there is no FAB. `heroTag: null`, because it sits outside any route. |
| Editor | A rounded panel. Its label reads "Editing drafts · *label*" (this app passes the Firebase project id as `label`), or "Tap a text to edit it" in pick mode. Below are the buttons. |

| Button | Action |
| --- | --- |
| Cursor (`ads_click`) | `EditorToolsCubit.togglePickMode()` |
| Highlight (`highlight_alt`) | `EditorToolsCubit.toggleHighlight()` |
| Table (`table_rows_outlined`), with a badge | Pushes `L10nKeyTablePage` on the app's Navigator. The badge shows the number of unpublished key/language pairs. |
| Logout | `InContextEditor.onSignOut` (in this app, `FirebaseL10nAccessDataSource.signOut`). Only shown when `onSignOut` is set. |

Pick and Highlight use `IconButton.isSelected`, so they show as toggled on.
Every button has a tooltip.

The package never signs anyone in itself. Signing out only changes what the
access data source's `watchEditor()` emits, and the overlay follows.

## 7. What it can't find

| Case | Why | Workaround |
| --- | --- | --- |
| String changed after localization (`substring`, `toUpperCase()`, `split`, joining) | The tag is cut off or no longer at the end | Edit from the key table |
| Text drawn with `CustomPainter` or `TextPainter` directly | There is no `RenderParagraph` to read | Edit from the key table |
| Text in images, or in platform views (WebView, maps) | Not in Flutter's render tree | Not editable in context |
| Text under `ExcludeSemantics` | Skipped by the highlight walk (§5.1); picking still works through the hit test | None needed |
| `Tooltip` messages, `Semantics` labels | Not shown as a paragraph until they appear | Pick the tooltip while it's visible, or use the key table |

## 8. Tests

[`tagged_text_finder_test.dart`](../../l10n_in_context/test/presentation/tagged_text_finder_test.dart)
pumps a real `MaterialApp` and checks that:

- tapping plain text, and text inside a `FilledButton`, returns the right
  key, and untagged text returns none;
- text under `IgnorePointer` is found through the bounds fallback;
- after pushing a route, only the new route's text is reported;
- tag indexes outside the catalog are ignored.

[`in_context_editor_test.dart`](../../l10n_in_context/test/presentation/in_context_editor_test.dart)
covers the overlay end to end: no Edit button without `onRequestAccess`,
and an editor picking a text, editing it and seeing the draft live.
