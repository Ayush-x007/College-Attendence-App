// This is a basic Flutter widget test customized for the AttendanceApp.
import 'package:flutter_test/flutter_test.dart';

// Make sure this import points to your actual main.dart file
import 'package:flutter_application_1/main.dart'; 

void main() {
  testWidgets('Login screen renders correctly smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AttendanceApp());

    // Verify that the Login Screen loads by looking for specific text
    expect(find.text('Student Portal'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);

    // Verify that the input fields are present
    expect(find.text('Registration Number'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify that the Login button is present
    expect(find.text('LOGIN'), findsOneWidget);

    // Verify that there is no counter text '0' from the old default app
    expect(find.text('0'), findsNothing);
  });
}