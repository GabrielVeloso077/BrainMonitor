// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brainmonitor/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:brainmonitor/firebase_options.dart';

void main() {
  // 1️⃣ Garante que o binding de testes é inicializado
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ Inicializa o Firebase antes de qualquer uso nos testes
  setUpAll(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  testWidgets('Contador incrementa smoke test', (WidgetTester tester) async {
    // 3️⃣ Carrega o widget principal
    await tester.pumpWidget(const MyApp());

    // Verifica o “0” inicial
    expect(find.text('0'), findsOneWidget);

    // Toca no botão “+”
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Agora deve existir “1”
    expect(find.text('1'), findsOneWidget);
  });
}
