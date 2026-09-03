// InterTaxi Widget Tests
// Premium quality tests for splash screen and core functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intertaxi/main.dart';

void main() {
  testWidgets('Splash screen displays logo and loading indicator', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const InterTaxiApp());
    await tester.pumpAndSettle();

    // Verify that the InterTaxi logo is displayed
    expect(find.text('InterTaxi'), findsOneWidget);
    expect(find.text('Your ride, your way'), findsOneWidget);

    // Verify that the loading indicator is displayed
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify the app title
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Splash screen has correct background color', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const InterTaxiApp());

    // Find the Scaffold widget
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(SplashScreen),
        matching: find.byType(Scaffold),
      ),
    );

    // Verify background color (white)
    expect(scaffold.backgroundColor, Colors.white);
  });

  testWidgets('Logo icon is displayed correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const InterTaxiApp());

    // Verify the taxi icon is present
    expect(find.byIcon(Icons.local_taxi_rounded), findsOneWidget);
  });

  testWidgets('registration stores a clean full name', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: RegistrationScreen()));

    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(4));

    await tester.enterText(textFields.at(0), 'Али');
    await tester.enterText(textFields.at(1), 'Сайф');
    await tester.enterText(textFields.at(2), '1995');
    await tester.enterText(textFields.at(3), '900000000');

    final submitButton = find.widgetWithText(ElevatedButton, 'Идома додан');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_name'), 'Али Сайф');
  });
}
