import 'dart:math';

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/local_database.dart';

/// Source de vérité unique avec gestion locale globale
class AppData extends ChangeNotifier {
  final String nomPharmacie = 'PharmaFody';

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  final List<Medicament> medicaments = [];
  final List<Vente> ventes = [];
  final List<Achat> achats = [];
  final List<Employe> employes = [];
  final List<MouvementStock> mouvements = [];

  final List<VenteItem> panier = [];
  double remiseEnCours = 0;

  bool _chargementInitial = true;
  bool get chargementInitial => _chargementInitial;

  final Random _rng = Random();

  AppData() {
    _loadInitialData();
  }

  /// Génère un identifiant unique en combinant l'horloge (microsecondes,
  /// donc pas de perte de précision comme avec un simple `substring`) et un
  /// suffixe aléatoire. Évite les collisions d'ID rencontrées auparavant
  /// (ex: deux médicaments créés à quelques secondes d'intervalle pouvaient
  /// générer le même identifiant et s'écraser silencieusement en base).
  String _genererIdUnique(String prefixe) {
    final horodatage = DateTime.now().microsecondsSinceEpoch;
    final suffixe = _rng.nextInt(9000) + 1000;
    return '$prefixe$horodatage$suffixe';
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> _loadInitialData() async {
    await fetchMedicaments();
    await fetchVentes();
    await fetchAchats();
    await fetchEmployes();
    await fetchMouvements();
    _chargementInitial = false;
    notifyListeners();
  }

  // ---------------- AUTH ----------------
  Future<bool> login(String username, String password) async {
    final user = await LocalDatabase.instance.getUser(username, password);
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> registerUser({required String username, required String name, required String password}) async {
    final newUser = User(username: username, name: name, password: password, role: 'Pharmacien');
    await LocalDatabase.instance.registerUser(newUser);
    _currentUser = newUser;
    notifyListeners();
    return true;
  }

  Future<void> updateProfile({required String name, required String password, String? imagePath}) async {
    if (_currentUser != null) {
      _currentUser!.name = name;
      _currentUser!.password = password;
      if (imagePath != null) _currentUser!.imagePath = imagePath;
      await LocalDatabase.instance.updateUser(_currentUser!);
      notifyListeners();
    }
  }

  // ---------------- MÉDICAMENTS ----------------
  Future<void> fetchMedicaments() async {
    final List<Medicament> dbMeds = await LocalDatabase.instance.getAllMedicaments();
    medicaments.clear();
    medicaments.addAll(dbMeds);
    notifyListeners();
  }

  Future<void> ajouterMedicament(Medicament m) async {
    await LocalDatabase.instance.insertMedicament(m);
    medicaments.add(m);
    notifyListeners();
  }

  Future<void> modifierMedicament(Medicament m) async {
    final index = medicaments.indexWhere((e) => e.id == m.id);
    if (index != -1) {
      await LocalDatabase.instance.updateMedicament(m);
      medicaments[index] = m;
      notifyListeners();
    }
  }

  Future<void> supprimerMedicament(String id) async {
    await LocalDatabase.instance.deleteMedicament(id);
    medicaments.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  String genererIdMedicament() => _genererIdUnique('MED');

  /// Générateur d'ID générique, exposé pour les autres écrans (employés,
  /// achats...) afin qu'ils n'aient plus à fabriquer leur propre ID à partir
  /// de `millisecondsSinceEpoch`.
  String genererId(String prefixe) => _genererIdUnique(prefixe);

  // ---------------- ACHATS ----------------
  Future<void> fetchAchats() async {
    final List<Achat> dbAchats = await LocalDatabase.instance.getAllAchats();
    achats.clear();
    achats.addAll(dbAchats);
    notifyListeners();
  }

  Future<void> ajouterAchat(Achat a) async {
    await LocalDatabase.instance.insertAchat(a);
    achats.add(a);
    notifyListeners();
  }

  Future<void> receptionnerAchat(String achatId) async {
    final index = achats.indexWhere((a) => a.id == achatId);
    if (index != -1) {
      achats[index].statut = 'Reçu';
      await LocalDatabase.instance.updateAchatStatut(achatId, 'Reçu');
      for (var ligne in achats[index].lignes) {
        final medIdx = medicaments.indexWhere((m) => m.nomCommercial == ligne.medicamentNom);
        if (medIdx != -1) await ajusterStock(medicaments[medIdx].id, ligne.quantite, TypeMouvement.entree);
      }
      notifyListeners();
    }
  }

  // ---------------- EMPLOYÉS ----------------
  Future<void> fetchEmployes() async {
    final List<Employe> dbEmployes = await LocalDatabase.instance.getAllEmployes();
    employes.clear();
    employes.addAll(dbEmployes);
    notifyListeners();
  }

  Future<void> ajouterEmploye(Employe e) async {
    await LocalDatabase.instance.insertEmploye(e);
    employes.add(e);
    notifyListeners();
  }

  Future<void> supprimerEmploye(String id) async {
    await LocalDatabase.instance.deleteEmploye(id);
    employes.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // ---------------- VENTES & STOCK ----------------
  /// Retourne `true` si l'article a bien été ajouté/incrémenté. Refuse si la
  /// quantité demandée dépasserait le stock réellement disponible (protège
  /// contre la vente d'articles qu'on n'a plus en rayon).
  bool ajouterAuPanier(Medicament m) {
    final existant = panier.indexWhere((i) => i.medicamentId == m.id);
    if (existant != -1) {
      if (panier[existant].quantite + 1 > m.stock) return false;
      panier[existant].quantite++;
    } else {
      if (m.stock <= 0) return false;
      panier.add(VenteItem(
        medicamentId: m.id,
        nom: m.nomCommercial,
        prixUnitaire: m.prixVente,
        quantite: 1,
        requiresOrdonnance: m.surOrdonnance,
        ordonnanceValide: !m.surOrdonnance,
      ));
    }
    notifyListeners();
    return true;
  }

  void definirOrdonnanceValide(String medicamentId, bool valide) {
    final item = panier.firstWhere((i) => i.medicamentId == medicamentId, orElse: () => VenteItem(medicamentId: '', nom: '', prixUnitaire: 0, quantite: 0));
    if (item.medicamentId.isNotEmpty) {
      item.ordonnanceValide = valide;
      notifyListeners();
    }
  }

  List<VenteItem> get ordonnanceItemsNonValides => panier.where((i) => i.requiresOrdonnance && !i.ordonnanceValide).toList();
  bool get panierOrdonnancesValides => ordonnanceItemsNonValides.isEmpty;

  /// Retourne `true` si la quantité a bien été modifiée. `orElse` évite un
  /// crash (`StateError`) si l'article a été retiré du panier entre-temps
  /// (ex: double-tap rapide). La borne haute est désormais le stock réel du
  /// médicament, pas une constante arbitraire (9999), pour ne pas pouvoir
  /// mettre en panier plus que ce qui est disponible.
  bool changerQuantitePanier(String id, int delta) {
    final item = panier.firstWhere(
      (i) => i.medicamentId == id,
      orElse: () => VenteItem(medicamentId: '', nom: '', prixUnitaire: 0, quantite: 0),
    );
    if (item.medicamentId.isEmpty) return false;

    final medIdx = medicaments.indexWhere((m) => m.id == id);
    final stockMax = medIdx != -1 ? medicaments[medIdx].stock : 9999;
    final nouvelleQuantite = item.quantite + delta;
    if (nouvelleQuantite > stockMax) return false;

    item.quantite = nouvelleQuantite.clamp(1, stockMax < 1 ? 1 : stockMax);
    notifyListeners();
    return true;
  }
  void retirerDuPanier(String id) { panier.removeWhere((i) => i.medicamentId == id); notifyListeners(); }
  void viderPanier() { panier.clear(); remiseEnCours = 0; notifyListeners(); }
  void definirRemise(double p) { remiseEnCours = p; notifyListeners(); }
  double get sousTotalPanier => panier.fold(0, (sum, i) => sum + i.sousTotal);
  double get remiseMontantPanier => sousTotalPanier * remiseEnCours / 100;
  double get totalPanier => sousTotalPanier - remiseMontantPanier;

  Future<Vente> encaisser({required String modePaiement}) async {
    if (panier.isEmpty) {
      throw Exception('Le panier est vide.');
    }
    if (!panierOrdonnancesValides) {
      throw Exception('Certaines ordonnances ne sont pas validées.');
    }

    // Vérifie AVANT d'encaisser que le stock couvre chaque article. Avant ce
    // correctif, la vente était enregistrée et facturée même quand le stock
    // était insuffisant, car le retour (bool) de `ajusterStock` n'était
    // jamais vérifié : le client payait un article qui, en réalité, ne
    // quittait jamais le rayon.
    for (final item in panier) {
      final medIdx = medicaments.indexWhere((m) => m.id == item.medicamentId);
      if (medIdx == -1) {
        throw Exception('${item.nom} n\'existe plus dans le catalogue.');
      }
      if (medicaments[medIdx].stock < item.quantite) {
        throw Exception(
          'Stock insuffisant pour ${item.nom} (disponible : ${medicaments[medIdx].stock}, demandé : ${item.quantite}).',
        );
      }
    }

    final vente = Vente(
      id: _genererIdUnique('VNT'),
      date: DateTime.now(),
      items: List.from(panier),
      remisePourcent: remiseEnCours,
      modePaiement: modePaiement,
    );

    for (var item in vente.items) {
      final ok = await ajusterStock(item.medicamentId, -item.quantite, TypeMouvement.sortie);
      if (!ok) {
        // Ne devrait plus arriver grâce à la vérification préalable, mais on
        // garde le contrôle par sécurité (ex: modification concurrente).
        throw Exception('Stock insuffisant pour ${item.nom}, vente annulée.');
      }
    }
    await LocalDatabase.instance.insertVente(vente);
    ventes.insert(0, vente);

    viderPanier();
    notifyListeners();
    return vente;
  }

  /// Retourne `true` si l'ajustement a été appliqué. Refuse si le stock
  /// résultant serait négatif. Utilisée par la réception de bons de
  /// commande et par l'encaissement d'une vente.
  Future<bool> ajusterStock(String medicamentId, int quantite, TypeMouvement type) async {
    final index = medicaments.indexWhere((m) => m.id == medicamentId);
    if (index == -1) return false;
    final nouveauStock = medicaments[index].stock + quantite;
    if (nouveauStock < 0) return false;
    medicaments[index].stock = nouveauStock;
    await LocalDatabase.instance.updateMedicament(medicaments[index]);
    final mouvement = MouvementStock(
      id: _genererIdUnique('MVT'),
      date: DateTime.now(),
      medicamentNom: medicaments[index].nomCommercial,
      type: type,
      quantite: quantite,
      utilisateur: _currentUser?.name ?? 'Système',
    );
    await LocalDatabase.instance.insertMouvement(mouvement);
    mouvements.insert(0, mouvement);
    notifyListeners();
    return true;
  }

  // ---------------- HISTORIQUE ----------------
  Future<void> fetchVentes() async {
    final List<Vente> dbVentes = await LocalDatabase.instance.getAllVentes();
    ventes.clear();
    ventes.addAll(dbVentes);
    notifyListeners();
  }

  Future<void> fetchMouvements() async {
    final List<MouvementStock> dbMouvements = await LocalDatabase.instance.getAllMouvements();
    mouvements.clear();
    mouvements.addAll(dbMouvements);
    notifyListeners();
  }

  // --- STATS & ALERTES ---
  List<Medicament> get produitsEnRupture => medicaments.where((m) => m.enRupture).toList();
  List<Medicament> get produitsBientotExpires => medicaments.where((m) => m.bientotExpire).toList();

  bool _estAujourdhui(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  List<Vente> get ventesDuJour => ventes.where((v) => _estAujourdhui(v.date)).toList();
  double get chiffreAffairesJour => ventesDuJour.fold(0, (sum, v) => sum + v.total);
  int get nombreVentesJour => ventesDuJour.length;
  double get margeBeneficiaireJour {
    double marge = 0;
    for (var v in ventesDuJour) {
      for (var item in v.items) {
        final medIdx = medicaments.indexWhere((m) => m.id == item.medicamentId);
        if (medIdx == -1) continue;
        marge += (item.prixUnitaire - medicaments[medIdx].prixAchat) * item.quantite;
      }
      marge -= v.remiseMontant;
    }
    return marge;
  }
  List<double> get ventesSeptJours {
    final aujourdhui = DateTime.now();
    return List.generate(7, (i) {
      final jour = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day).subtract(Duration(days: 6 - i));
      return ventes
          .where((v) => v.date.year == jour.year && v.date.month == jour.month && v.date.day == jour.day)
          .fold<double>(0, (sum, v) => sum + v.total);
    });
  }

  List<Medicament> get topProduits {
    final Map<String, int> quantitesParMedicament = {};
    for (final v in ventes) {
      for (final item in v.items) {
        quantitesParMedicament[item.medicamentId] = (quantitesParMedicament[item.medicamentId] ?? 0) + item.quantite;
      }
    }
    final medsAvecVentes = medicaments.where((m) => quantitesParMedicament.containsKey(m.id)).toList();
    medsAvecVentes.sort((a, b) => quantitesParMedicament[b.id]!.compareTo(quantitesParMedicament[a.id]!));
    return medsAvecVentes.take(5).toList();
  }

  /// Quantité totale vendue pour un médicament donné, toutes ventes
  /// confondues. Utilisée pour mettre en avant l'information la plus
  /// pertinente d'un classement "Top produits" : le volume vendu, pas
  /// seulement le prix unitaire.
  int quantiteVendue(String medicamentId) {
    int total = 0;
    for (final v in ventes) {
      for (final item in v.items) {
        if (item.medicamentId == medicamentId) total += item.quantite;
      }
    }
    return total;
  }

  Map<String, double> get ventesParCategorie {
    final Map<String, double> totaux = {};
    for (final v in ventes) {
      for (final item in v.items) {
        final medIdx = medicaments.indexWhere((m) => m.id == item.medicamentId);
        final categorie = medIdx != -1 ? medicaments[medIdx].categorie : 'Autre';
        totaux[categorie] = (totaux[categorie] ?? 0) + item.sousTotal;
      }
    }
    return totaux;
  }
}
