import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pet_diary/main.dart';

void main() {
  testWidgets('HomeScreen renders pet info and FAB', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PetDiaryApp(showOnboarding: false));

    expect(find.text('몽이'), findsOneWidget);
    expect(find.text('오늘 기록'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
