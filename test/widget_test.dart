import 'package:flutter_test/flutter_test.dart';
import 'package:dnsly_app/app.dart';

void main() {
  testWidgets('DNSly app shell renders all tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const DNSlyApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('DNS Scan'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
