import 'package:flutter_test/flutter_test.dart';
import 'package:xapk_installer/main.dart';

void main() {
  testWidgets('XapkInstallerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const XapkInstallerApp());
    expect(find.text('XAPK Installer'), findsOneWidget);
  });
}
