import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VyayamaApp()));
    await tester.pump();
    expect(find.byType(VyayamaApp), findsOneWidget);
  });
}
