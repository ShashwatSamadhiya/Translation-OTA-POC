import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/src/core/l10n/l10n_key_tag.dart';
import 'package:tolgee_poc/src/features/l10n_editor/presentation/widgets/tagged_text_finder.dart';

void main() {
  final rootKey = GlobalKey();
  final navigatorKey = GlobalKey<NavigatorState>();

  RenderBox root(WidgetTester tester) =>
      rootKey.currentContext!.findRenderObject()! as RenderBox;

  Future<void> pump(WidgetTester tester, Widget home) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) => KeyedSubtree(key: rootKey, child: child!),
      home: home,
    ),
  );

  testWidgets('picks the key of tapped text, including inside buttons', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: Column(
          children: [
            Text(L10nKeyTag.tag('welcomeTitle', 'Welcome')),
            FilledButton(
              onPressed: () {},
              child: Text(L10nKeyTag.tag('retry', 'Retry')),
            ),
            const Text('Untagged'),
          ],
        ),
      ),
    );

    Offset centerOf(String text) => tester.getCenter(find.textContaining(text));
    expect(keysAt(root(tester), centerOf('Welcome')), ['welcomeTitle']);
    expect(keysAt(root(tester), centerOf('Retry')), ['retry']);
    expect(keysAt(root(tester), centerOf('Untagged')), isEmpty);
  });

  testWidgets('falls back to bounds for text under IgnorePointer', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: IgnorePointer(
          child: Text(L10nKeyTag.tag('getStarted', 'Get started')),
        ),
      ),
    );
    final center = tester.getCenter(find.textContaining('Get started'));
    expect(keysAt(root(tester), center), ['getStarted']);
  });

  testWidgets('highlights only text on the visible route', (tester) async {
    await pump(
      tester,
      Scaffold(body: Text(L10nKeyTag.tag('welcomeTitle', 'Home'))),
    );
    expect(findTaggedTexts(root(tester)).single.keys, ['welcomeTitle']);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Text(L10nKeyTag.tag('retry', 'Next'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(findTaggedTexts(root(tester)).expand((t) => t.keys).toList(), [
      'retry',
    ]);
  });
}
