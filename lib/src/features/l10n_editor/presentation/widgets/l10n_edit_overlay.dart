import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/env.dart';
import '../../../../presentation/theme/spacing.dart';
import '../cubit/l10n_editor_cubit.dart';
import '../cubit/l10n_editor_state.dart';
import '../pages/l10n_key_table_page.dart';
import 'edit_key_dialog.dart';
import 'sign_in_dialog.dart';
import 'tagged_text_finder.dart';

/// Wraps the app (via `MaterialApp.builder`) with the in-context editor:
/// an Edit button, the editor toolbar, pick mode and the highlight layer.
///
/// It sits above the Navigator, so dialogs and pages are opened through
/// [navigatorKey]. Editor UI text is plain English and never localized, so
/// it carries no key tags and can't be picked by mistake.
class L10nEditOverlay extends StatefulWidget {
  const L10nEditOverlay({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<L10nEditOverlay> createState() => _L10nEditOverlayState();
}

class _L10nEditOverlayState extends State<L10nEditOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _contentKey = GlobalKey();

  /// Re-measures highlights every frame while they are shown, so they follow
  /// scrolling and route changes.
  late final Ticker _ticker = createTicker((_) => _updateHighlights());
  List<Rect> _highlights = const [];

  RenderBox? get _contentBox =>
      _contentKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _syncHighlight(bool on) {
    if (on && !_ticker.isActive) {
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
      setState(() => _highlights = const []);
    }
  }

  void _updateHighlights() {
    final box = _contentBox;
    if (box == null || !box.hasSize) return;
    final rects = [for (final tagged in findTaggedTexts(box)) tagged.rect];
    if (!listEquals(rects, _highlights)) setState(() => _highlights = rects);
  }

  Future<void> _pick(Offset globalPosition) async {
    context.read<L10nEditorCubit>().setPickMode(false);
    final box = _contentBox;
    final navigatorContext = widget.navigatorKey.currentContext;
    if (box == null || navigatorContext == null) return;
    final keys = keysAt(box, globalPosition);
    if (keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This text isn't from the ARB files.")),
      );
      return;
    }
    final key = keys.length == 1
        ? keys.single
        : await showDialog<String>(
            context: navigatorContext,
            builder: (context) => SimpleDialog(
              title: const Text('Which string?'),
              children: [
                for (final key in keys)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, key),
                    child: Text(key),
                  ),
              ],
            ),
          );
    if (key == null || !navigatorContext.mounted) return;
    await showEditKeyDialog(navigatorContext, key);
  }

  void _openSignIn() {
    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) return;
    context.read<L10nEditorCubit>().clearError();
    showDialog<void>(
      context: navigatorContext,
      builder: (_) => const SignInDialog(),
    );
  }

  void _openKeyTable() {
    widget.navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => const L10nKeyTablePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return BlocConsumer<L10nEditorCubit, L10nEditorState>(
      listener: (context, state) {
        _syncHighlight(state.isEditor && state.highlight);
        // Sign-in errors are shown inside the sign-in dialog instead.
        final error = state.error;
        if (error != null && state.isEditor) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error)));
          context.read<L10nEditorCubit>().clearError();
        }
      },
      builder: (context, state) {
        final cubit = context.read<L10nEditorCubit>();
        return Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(key: _contentKey, child: widget.child),
            if (state.isEditor && state.highlight)
              IgnorePointer(
                child: CustomPaint(
                  painter: _HighlightPainter(_highlights, colors.tertiary),
                ),
              ),
            if (state.isEditor && state.pickMode)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _pick(details.globalPosition),
                child: ColoredBox(
                  color: colors.primary.withValues(alpha: 0.06),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: paddingMd,
                  child: state.isEditor
                      ? _EditorToolbar(
                          state: state,
                          onPick: cubit.togglePickMode,
                          onHighlight: cubit.toggleHighlight,
                          onKeys: _openKeyTable,
                          onSignOut: cubit.signOut,
                        )
                      : FloatingActionButton.small(
                          heroTag: null,
                          onPressed: state.status == EditorStatus.restoring
                              ? null
                              : _openSignIn,
                          child: const Icon(Icons.edit_note),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.state,
    required this.onPick,
    required this.onHighlight,
    required this.onKeys,
    required this.onSignOut,
  });

  final L10nEditorState state;
  final VoidCallback onPick;
  final VoidCallback onHighlight;
  final VoidCallback onKeys;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unpublished = state.unpublishedKeys.values.fold(
      0,
      (count, keys) => count + keys.length,
    );
    return Material(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Spacing.md),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: Text(
                state.pickMode
                    ? 'Tap a text to edit it'
                    : 'Editing drafts · ${Env.firebaseProjectId}',
                style: theme.textTheme.labelSmall,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  isSelected: state.pickMode,
                  onPressed: onPick,
                  icon: const Icon(Icons.ads_click),
                ),
                IconButton(
                  isSelected: state.highlight,
                  onPressed: onHighlight,
                  icon: const Icon(Icons.highlight_alt),
                ),
                IconButton(
                  onPressed: onKeys,
                  icon: Badge(
                    isLabelVisible: unpublished > 0,
                    label: Text('$unpublished'),
                    child: const Icon(Icons.table_rows_outlined),
                  ),
                ),
                IconButton(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter(this.rects, this.color);

  final List<Rect> rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final rect in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      !listEquals(old.rects, rects) || old.color != color;
}
