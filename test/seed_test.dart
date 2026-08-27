import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:PharmaFody/services/local_database.dart';

void main() {
  // Les tests tournent sur le moteur de test (pas Android/iOS), on force
  // donc le driver SQLite FFI comme le fait déjà LocalDatabase sur desktop.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('Initialise la DB avec un compte admin par défaut et aucune donnée mock', (WidgetTester tester) async {
    WidgetsFlutterBinding.ensureInitialized();
    await LocalDatabase.instance.init();

    final admin = await LocalDatabase.instance.getUser('admin', 'admin');
    final medicaments = await LocalDatabase.instance.getAllMedicaments();

    expect(admin, isNotNull);
    expect(admin!.role, 'Administrateur');
    // Aucun médicament factice : la base démarre vide, l'utilisateur ajoute
    // ses propres produits depuis le module Médicaments.
    expect(medicaments, isEmpty);

    await LocalDatabase.instance.close();
  });
}
