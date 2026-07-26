import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:velaplayer/main.dart';

void main() {
  testWidgets('App startet und zeigt die Startseite', (WidgetTester tester) async {
    await tester.pumpWidget(const VelaApp());
    expect(find.text('Live-TV'), findsOneWidget);
  });
}
