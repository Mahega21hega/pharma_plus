import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/models.dart';

/// Accès à la base de données locale SQLite de l'application.
///
/// Sur Android / iOS, `sqflite` utilise le moteur SQLite natif de l'OS.
/// Sur desktop (Windows / Linux / macOS), on bascule sur `sqflite_common_ffi`
/// qui fournit le même driver SQLite via FFI, afin de garder une seule
/// implémentation de code pour toutes les plateformes non-web.
class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();

  LocalDatabase._init();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    // Sur desktop, sqflite s'appuie sur sqflite_common_ffi (pas de plugin
    // natif disponible). Sur Android/iOS, on garde l'implémentation par
    // défaut de sqflite qui est déjà optimisée pour mobile.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'PharmaFody.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Sans ceci, les contraintes `ON DELETE CASCADE` (vente_items,
        // achat_lignes) sont ignorées par SQLite : supprimer une vente ou
        // un achat laisserait des lignes orphelines dans les tables enfants.
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Crée les tables ajoutées après la version 1 (ventes, achats, employés,
  /// mouvements de stock) sur les installations existantes qui n'avaient que
  /// `users` et `medicaments`. `IF NOT EXISTS` rend l'opération sûre même si
  /// elle est rejouée.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        username TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        imagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medicaments (
        id TEXT PRIMARY KEY,
        nomCommercial TEXT NOT NULL,
        dci TEXT NOT NULL,
        categorie TEXT NOT NULL,
        fabricant TEXT NOT NULL,
        prixAchat REAL NOT NULL,
        prixVente REAL NOT NULL,
        stock INTEGER NOT NULL,
        stockMin INTEGER NOT NULL,
        dateFabrication TEXT NOT NULL,
        dateExpiration TEXT NOT NULL,
        numeroLot TEXT NOT NULL,
        codeBarres TEXT NOT NULL,
        emplacement TEXT NOT NULL,
        surOrdonnance INTEGER NOT NULL
      )
    ''');

    await _createV2Tables(db);

    // Seul un compte administrateur par défaut est créé, pour permettre la
    // première connexion. Aucune donnée métier (médicaments, ventes...)
    // n'est pré-remplie : la pharmacie démarre avec une base vide.
    await db.insert('users', {
      'username': 'admin',
      'name': 'Admin Pharma',
      'password': 'admin',
      'role': 'Administrateur',
      'imagePath': null,
    });
  }

  /// Tables ajoutées en version 2 (ventes, achats, employés, mouvements de
  /// stock). `IF NOT EXISTS` permet de partager ce code entre `_onCreate`
  /// (nouvelle installation) et `_onUpgrade` (installation existante).
  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventes (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        remisePourcent REAL NOT NULL,
        modePaiement TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS vente_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venteId TEXT NOT NULL,
        medicamentId TEXT NOT NULL,
        nom TEXT NOT NULL,
        prixUnitaire REAL NOT NULL,
        quantite INTEGER NOT NULL,
        requiresOrdonnance INTEGER NOT NULL,
        ordonnanceValide INTEGER NOT NULL,
        FOREIGN KEY (venteId) REFERENCES ventes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS achats (
        id TEXT PRIMARY KEY,
        fournisseurNom TEXT NOT NULL,
        fournisseurTelephone TEXT NOT NULL,
        fournisseurEmail TEXT NOT NULL,
        fournisseurAdresse TEXT NOT NULL,
        date TEXT NOT NULL,
        statut TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS achat_lignes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        achatId TEXT NOT NULL,
        medicamentNom TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        prixUnitaire REAL NOT NULL,
        FOREIGN KEY (achatId) REFERENCES achats (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS employes (
        id TEXT PRIMARY KEY,
        nom TEXT NOT NULL,
        role TEXT NOT NULL,
        telephone TEXT NOT NULL,
        statut TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS mouvements_stock (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        medicamentNom TEXT NOT NULL,
        type TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        utilisateur TEXT NOT NULL
      )
    ''');
  }

  Future<void> init() async {
    await _database;
  }

  // ---------------- UTILISATEURS ----------------
  Future<User?> getUser(String username, String password) async {
    final db = await _database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<void> updateUser(User user) async {
    final db = await _database;
    await db.update(
      'users',
      user.toMap(),
      where: 'username = ?',
      whereArgs: [user.username],
    );
  }

  Future<void> registerUser(User user) async {
    final db = await _database;
    final existing = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [user.username],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('Utilisateur déjà existant');
    }
    await db.insert('users', user.toMap());
  }

  // ---------------- MÉDICAMENTS ----------------
  Future<List<Medicament>> getAllMedicaments() async {
    final db = await _database;
    final rows = await db.query('medicaments', orderBy: 'nomCommercial ASC');
    return rows.map((row) => Medicament.fromMap(_medicamentFromDb(row))).toList();
  }

  Future<void> insertMedicament(Medicament m) async {
    final db = await _database;
    await db.insert(
      'medicaments',
      _medicamentToDb(m),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMedicament(Medicament m) async {
    final db = await _database;
    await db.update(
      'medicaments',
      _medicamentToDb(m),
      where: 'id = ?',
      whereArgs: [m.id],
    );
  }

  Future<void> deleteMedicament(String id) async {
    final db = await _database;
    await db.delete('medicaments', where: 'id = ?', whereArgs: [id]);
  }

  // SQLite ne connaît pas de type booléen natif : on stocke 0/1 pour
  // `surOrdonnance` et on le reconvertit en bool à la lecture.
  Map<String, dynamic> _medicamentToDb(Medicament m) {
    final map = m.toMap();
    map['surOrdonnance'] = m.surOrdonnance ? 1 : 0;
    return map;
  }

  Map<String, dynamic> _medicamentFromDb(Map<String, dynamic> row) {
    final map = Map<String, dynamic>.from(row);
    map['surOrdonnance'] = row['surOrdonnance'] == 1;
    return map;
  }

  // ---------------- VENTES ----------------
  Future<List<Vente>> getAllVentes() async {
    final db = await _database;
    final ventesRows = await db.query('ventes', orderBy: 'date DESC');
    final result = <Vente>[];
    for (final row in ventesRows) {
      final itemRows = await db.query('vente_items', where: 'venteId = ?', whereArgs: [row['id']]);
      final items = itemRows
          .map((r) => VenteItem(
                medicamentId: r['medicamentId'] as String,
                nom: r['nom'] as String,
                prixUnitaire: r['prixUnitaire'] as double,
                quantite: r['quantite'] as int,
                requiresOrdonnance: r['requiresOrdonnance'] == 1,
                ordonnanceValide: r['ordonnanceValide'] == 1,
              ))
          .toList();
      result.add(Vente(
        id: row['id'] as String,
        date: DateTime.parse(row['date'] as String),
        items: items,
        remisePourcent: row['remisePourcent'] as double,
        modePaiement: row['modePaiement'] as String,
      ));
    }
    return result;
  }

  Future<void> insertVente(Vente v) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('ventes', {
        'id': v.id,
        'date': v.date.toIso8601String(),
        'remisePourcent': v.remisePourcent,
        'modePaiement': v.modePaiement,
      });
      for (final item in v.items) {
        await txn.insert('vente_items', {
          'venteId': v.id,
          'medicamentId': item.medicamentId,
          'nom': item.nom,
          'prixUnitaire': item.prixUnitaire,
          'quantite': item.quantite,
          'requiresOrdonnance': item.requiresOrdonnance ? 1 : 0,
          'ordonnanceValide': item.ordonnanceValide ? 1 : 0,
        });
      }
    });
  }

  // ---------------- ACHATS ----------------
  Future<List<Achat>> getAllAchats() async {
    final db = await _database;
    final achatsRows = await db.query('achats', orderBy: 'date DESC');
    final result = <Achat>[];
    for (final row in achatsRows) {
      final ligneRows = await db.query('achat_lignes', where: 'achatId = ?', whereArgs: [row['id']]);
      final lignes = ligneRows
          .map((r) => LigneAchat(
                medicamentNom: r['medicamentNom'] as String,
                quantite: r['quantite'] as int,
                prixUnitaire: r['prixUnitaire'] as double,
              ))
          .toList();
      result.add(Achat(
        id: row['id'] as String,
        fournisseurNom: row['fournisseurNom'] as String,
        fournisseurTelephone: row['fournisseurTelephone'] as String,
        fournisseurEmail: row['fournisseurEmail'] as String,
        fournisseurAdresse: row['fournisseurAdresse'] as String,
        date: DateTime.parse(row['date'] as String),
        lignes: lignes,
        statut: row['statut'] as String,
      ));
    }
    return result;
  }

  Future<void> insertAchat(Achat a) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('achats', {
        'id': a.id,
        'fournisseurNom': a.fournisseurNom,
        'fournisseurTelephone': a.fournisseurTelephone,
        'fournisseurEmail': a.fournisseurEmail,
        'fournisseurAdresse': a.fournisseurAdresse,
        'date': a.date.toIso8601String(),
        'statut': a.statut,
      });
      for (final ligne in a.lignes) {
        await txn.insert('achat_lignes', {
          'achatId': a.id,
          'medicamentNom': ligne.medicamentNom,
          'quantite': ligne.quantite,
          'prixUnitaire': ligne.prixUnitaire,
        });
      }
    });
  }

  Future<void> updateAchatStatut(String id, String statut) async {
    final db = await _database;
    await db.update('achats', {'statut': statut}, where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- EMPLOYÉS ----------------
  Future<List<Employe>> getAllEmployes() async {
    final db = await _database;
    final rows = await db.query('employes', orderBy: 'nom ASC');
    return rows
        .map((r) => Employe(
              id: r['id'] as String,
              nom: r['nom'] as String,
              role: r['role'] as String,
              telephone: r['telephone'] as String,
              statut: r['statut'] as String,
            ))
        .toList();
  }

  Future<void> insertEmploye(Employe e) async {
    final db = await _database;
    await db.insert('employes', {
      'id': e.id,
      'nom': e.nom,
      'role': e.role,
      'telephone': e.telephone,
      'statut': e.statut,
    });
  }

  Future<void> deleteEmploye(String id) async {
    final db = await _database;
    await db.delete('employes', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- MOUVEMENTS DE STOCK ----------------
  Future<List<MouvementStock>> getAllMouvements() async {
    final db = await _database;
    final rows = await db.query('mouvements_stock', orderBy: 'date DESC');
    return rows
        .map((r) => MouvementStock(
              id: r['id'] as String,
              date: DateTime.parse(r['date'] as String),
              medicamentNom: r['medicamentNom'] as String,
              type: TypeMouvement.values.firstWhere((t) => t.name == r['type']),
              quantite: r['quantite'] as int,
              utilisateur: r['utilisateur'] as String,
            ))
        .toList();
  }

  Future<void> insertMouvement(MouvementStock m) async {
    final db = await _database;
    await db.insert('mouvements_stock', {
      'id': m.id,
      'date': m.date.toIso8601String(),
      'medicamentNom': m.medicamentNom,
      'type': m.type.name,
      'quantite': m.quantite,
      'utilisateur': m.utilisateur,
    });
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
