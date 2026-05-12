import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scrapp/main.dart';

void main() {
  testWidgets('ScrappApp renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ScrappApp()));
    // App should render a MaterialApp with the Scrapp title.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
