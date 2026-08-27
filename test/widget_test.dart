import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PharmaFody/main.dart';

void main() {
  testWidgets('Vérification de l\'affichage de l\'écran de connexion', (WidgetTester tester) async {
    // Augmenter la taille de la fenêtre de test pour éviter les overflows
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;

    // Construction de l'application
    await tester.pumpWidget(const PharmaFodyApp());

    // On vérifie que le titre PharmaFody est présent (écran de login)
    expect(find.text('PharmaFody'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    
    // Reset view size
    addTearDown(tester.view.resetPhysicalSize);
  });
}
