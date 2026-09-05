import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intertaxi/screens/driver_home_screen.dart';

void main() {
  testWidgets('driver home shows the required tabs and announcement CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DriverHomeScreen(
          driverName: 'Ронанда',
          driverPhone: '+992900000000',
        ),
      ),
    );

    expect(find.text('Асосӣ'), findsOneWidget);
    expect(find.text('Сафар'), findsOneWidget);
    expect(find.text('Сообщения'), findsOneWidget);
    expect(find.text('Профил'), findsOneWidget);

    expect(find.text('Эълони нав'), findsOneWidget);
  });
}
