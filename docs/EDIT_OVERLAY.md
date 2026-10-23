# How `L10nEditOverlay` works

[`l10n_edit_overlay.dart`](../lib/src/features/l10n_editor/presentation/widgets/l10n_edit_overlay.dart)
is the on-screen part of in-context editing: the edit button, the editor
toolbar, pick mode and the highlight outlines. The render-tree searches it
relies on are in
[`tagged_text_finder.dart`](../lib/src/features/l10n_editor/presentation/widgets/tagged_text_finder.dart).

This page assumes you know that, in edit mode, every localized string ends
with an invisible key tag. [IN_CONTEXT_EDITING.md §3.3](IN_CONTEXT_EDITING.md#33-every-string-gets-an-invisible-tag)
explains the tag.

---

## 1. Where it sits in the widget tree

[`app.dart`](../lib/src/app.dart) installs it through `MaterialApp.builder`:

```dart
MaterialApp(
  navigatorKey: _navigatorKey,
  builder: (context, child) => L10nEditOverlay(
    navigatorKey: _navigatorKey,
    child: child!,          // child is the Navigator
  ),
  ...
)
```

```
MaterialApp
 └─ Theme, ScaffoldMessenger, Localizations, MediaQuery   ← available to the overlay
     └─ L10nEditOverlay                                   ← builder
         └─ Navigator (child)                             ← every route, dialog and page
```

Sitting **above the Navigator** has two consequences:

| Consequence | How the code handles it |
| --- | --- |
| It stays on screen across every route, so the toolbar is always visible | Nothing to do: that's the point |
| `showDialog(context)` and `Navigator.of(context)` don't work from the overlay's own `context` (there is no Navigator above it) | Dialogs and pages open through `navigatorKey.currentContext` and `navigatorKey.currentState` |
| There is no `Overlay` above it, so `Tooltip` would throw | The toolbar's buttons have no tooltips |
| `ScaffoldMessenger` *is* above it | Snackbars use `ScaffoldMessenger.of(context)` and appear on the current page's `Scaffold` |

The overlay is installed whenever edit mode is compiled in, signed in or
not, because the signed-out edit button lives in it too.

## 2. The layer stack

`build()` returns a `Stack` with `fit: StackFit.expand`. From bottom to top:

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
  and can't be picked by mistake.

## 3. State it reacts to

The overlay is a `BlocConsumer<L10nEditorCubit, L10nEditorState>`:

| State field | Effect |
| --- | --- |
| `status` | `restoring`: the edit button is disabled while the old session is checked. `signedOut` or `signingIn`: the edit button. `editor`: the toolbar. |
| `pickMode` | Adds or removes layer 3 |
| `highlight` | Adds or removes layer 2, and starts or stops the ticker (§5) |
| `unpublishedKeys` | Badge count on the key-table button |
| `error` | Shown as a snackbar, then cleared (signed-in editors only; sign-in errors are shown inside the sign-in dialog) |

## 4. Pick mode

### 4.1 Catching the tap

When `pickMode` is true, layer 3 is a full-screen
`GestureDetector(behavior: HitTestBehavior.opaque)` with a faint tint. The
opaque behaviour makes it win the tap, so the button or list tile
underneath **never fires**. That's why there's a separate pick mode instead
of, say, long-press, which would clash with the app's own gestures.

`onTapUp` calls `_pick(globalPosition)`, which first turns pick mode off,
so each pick is one tap.

### 4.2 Finding the text under the finger: `keysAt`

```dart
List<String> keysAt(RenderBox root, Offset globalPosition)
```

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

`toPlainText()` keeps the zero-width tag characters, and
`L10nKeyTag.keysIn` turns them back into key names. One paragraph can
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
route with the `L10nEditorCubit` still reachable (the cubit is provided
above `MaterialApp`).

## 5. Highlight

### 5.1 Finding every tagged text: `findTaggedTexts`

```dart
List<TaggedText> findTaggedTexts(RenderObject root)
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
              → findTaggedTexts(root)
              → setState only if the rectangles changed
```

The ticker is started and stopped from the bloc listener (`_syncHighlight`)
and disposed with the widget. When nothing moves, the rectangles stay the
same and there's no extra rebuild. Walking the tree each frame is cheap at
this size, and it only happens for a signed-in editor with Highlight on.

### 5.3 Painting

`_HighlightPainter` draws a 1.5 px rounded outline, inflated by 2 px, around
each rectangle, in the theme's `tertiary` colour. It repaints only when the
list of rectangles changes.

## 6. Toolbar and edit button

| State | Shown in the bottom-right corner |
| --- | --- |
| Not signed in | Small FAB (`Icons.edit_note`) that opens the sign-in dialog. `heroTag: null`, because it sits outside any route. |
| Signed in | A rounded panel. Its label reads "Editing drafts · *project-id*", or "Tap a text to edit it" in pick mode. Below are four buttons. |

| Button | Action |
| --- | --- |
| Cursor (`ads_click`) | `cubit.togglePickMode()` |
| Highlight (`highlight_alt`) | `cubit.toggleHighlight()` |
| Table (`table_rows_outlined`), with a badge | `navigatorKey.currentState.push(L10nKeyTablePage)`. The badge shows the number of unpublished key/language pairs. |
| Logout | `cubit.signOut()` |

Pick and Highlight use `IconButton.isSelected`, so they show as toggled on.

## 7. What it can't find

| Case | Why | Workaround |
| --- | --- | --- |
| String changed after localization (`substring`, `toUpperCase()`, `split`, joining) | The tag is cut off or no longer at the end | Edit from the key table |
| Text drawn with `CustomPainter` or `TextPainter` directly | There is no `RenderParagraph` to read | Edit from the key table |
| Text in images, or in platform views (WebView, maps) | Not in Flutter's render tree | Not editable in context |
| Text under `ExcludeSemantics` | Skipped by the highlight walk (§5.1); picking still works through the hit test | None needed |
| `Tooltip` messages, `Semantics` labels | Not shown as a paragraph until they appear | Pick the tooltip while it's visible, or use the key table |

## 8. Tests

[`tagged_text_finder_test.dart`](../test/features/l10n_editor/tagged_text_finder_test.dart)
pumps a real `MaterialApp` and checks that:

- tapping plain text, and text inside a `FilledButton`, returns the right
  key, and untagged text returns none;
- text under `IgnorePointer` is found through the bounds fallback;
- after pushing a route, only the new route's text is reported.
