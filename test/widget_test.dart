// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:treproject/main.dart';
import 'package:treproject/utils/barcode_manager.dart';
import 'package:treproject/services/api_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Cria manager e api service para teste
    final manager = BarcodeManager();
    final apiService = ApiService(
      barcodeManager: manager,
      apiUrl: 'http://localhost:3000',
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      barcodeManager: manager,
      apiService: apiService,
    ));

    // Verifica se a tela inicial está presente
    expect(find.text('Tela Inicial'), findsOneWidget);
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('Outra Tela'), findsOneWidget);
  });
}
