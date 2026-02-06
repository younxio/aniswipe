// Basic app test without authentication dependencies
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aniswipe/app.dart';

void main() {
  testWidgets('AniSwipe app basic smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: AniSwipeApp(),
      ),
    );

    // Wait for the app to load
    await tester.pumpAndSettle();

    // Verify that the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
