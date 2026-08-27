
/// ------------------ MÉDICAMENT ------------------
class Medicament {
  String id;
  String nomCommercial;
  String dci; // Dénomination Commune Internationale (nom générique)
  String categorie;
  String fabricant;
  double prixAchat;
  double prixVente;
  int stock;
  int stockMin;
  DateTime dateFabrication;
  DateTime dateExpiration;
  String numeroLot;
  String codeBarres;
  String emplacement;
  bool surOrdonnance;

  Medicament({
    required this.id,
    required this.nomCommercial,
    required this.dci,
    required this.categorie,
    required this.fabricant,
    required this.prixAchat,
    required this.prixVente,
    required this.stock,
    this.stockMin = 20,
    required this.dateFabrication,
    required this.dateExpiration,
    required this.numeroLot,
    required this.codeBarres,
    required this.emplacement,
    this.surOrdonnance = false,
  });

  bool get enRupture => stock <= stockMin;
  bool get bientotExpire =>
      dateExpiration.difference(DateTime.now()).inDays <= 60;

  Map<String, dynamic> toMap() => {
    'id': id,
    'nomCommercial': nomCommercial,
    'dci': dci,
    'categorie': categorie,
    'fabricant': fabricant,
    'prixAchat': prixAchat,
    'prixVente': prixVente,
    'stock': stock,
    'stockMin': stockMin,
    'dateFabrication': dateFabrication.toIso8601String(),
    'dateExpiration': dateExpiration.toIso8601String(),
    'numeroLot': numeroLot,
    'codeBarres': codeBarres,
    'emplacement': emplacement,
    'surOrdonnance': surOrdonnance,
  };

  factory Medicament.fromMap(Map<dynamic, dynamic> map) => Medicament(
    id: map['id'],
    nomCommercial: map['nomCommercial'],
    dci: map['dci'],
    categorie: map['categorie'],
    fabricant: map['fabricant'],
    prixAchat: map['prixAchat'],
    prixVente: map['prixVente'],
    stock: map['stock'],
    stockMin: map['stockMin'] ?? 20,
    dateFabrication: DateTime.parse(map['dateFabrication']),
    dateExpiration: DateTime.parse(map['dateExpiration']),
    numeroLot: map['numeroLot'],
    codeBarres: map['codeBarres'],
    emplacement: map['emplacement'],
    surOrdonnance: map['surOrdonnance'],
  );
}

/// ------------------ VENTE ------------------
class VenteItem {
  String medicamentId;
  String nom;
  double prixUnitaire;
  int quantite;
  bool requiresOrdonnance;
  bool ordonnanceValide;

  VenteItem({
    required this.medicamentId,
    required this.nom,
    required this.prixUnitaire,
    required this.quantite,
    this.requiresOrdonnance = false,
    this.ordonnanceValide = false,
  });

  double get sousTotal => prixUnitaire * quantite;

  Map<String, dynamic> toMap() => {
    'medicamentId': medicamentId,
    'nom': nom,
    'prixUnitaire': prixUnitaire,
    'quantite': quantite,
    'requiresOrdonnance': requiresOrdonnance,
    'ordonnanceValide': ordonnanceValide,
  };

  factory VenteItem.fromMap(Map<dynamic, dynamic> map) => VenteItem(
    medicamentId: map['medicamentId'],
    nom: map['nom'],
    prixUnitaire: map['prixUnitaire'],
    quantite: map['quantite'],
    requiresOrdonnance: map['requiresOrdonnance'] ?? false,
    ordonnanceValide: map['ordonnanceValide'] ?? false,
  );
}

class Vente {
  String id;
  DateTime date;
  List<VenteItem> items;
  double remisePourcent;
  String modePaiement;

  Vente({
    required this.id,
    required this.date,
    required this.items,
    this.remisePourcent = 0,
    this.modePaiement = 'Espèces',
  });

  double get sousTotal => items.fold(0, (sum, i) => sum + i.sousTotal);
  double get remiseMontant => sousTotal * remisePourcent / 100;
  double get total => sousTotal - remiseMontant;

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date.toIso8601String(),
    'items': items.map((e) => e.toMap()).toList(),
    'remisePourcent': remisePourcent,
    'modePaiement': modePaiement,
  };

  factory Vente.fromMap(Map<dynamic, dynamic> map) => Vente(
    id: map['id'],
    date: DateTime.parse(map['date']),
    items: (map['items'] as List).map((e) => VenteItem.fromMap(e)).toList(),
    remisePourcent: map['remisePourcent'] ?? 0,
    modePaiement: map['modePaiement'] ?? 'Espèces',
  );
}

/// ------------------ ACHAT / BON DE COMMANDE ------------------
class LigneAchat {
  String medicamentNom;
  int quantite;
  double prixUnitaire;

  LigneAchat({
    required this.medicamentNom,
    required this.quantite,
    required this.prixUnitaire,
  });

  double get total => quantite * prixUnitaire;
}

class Achat {
  String id;
  String fournisseurNom;
  String fournisseurTelephone;
  String fournisseurEmail;
  String fournisseurAdresse;
  DateTime date;
  List<LigneAchat> lignes;
  String statut; // "Commandé", "Reçu", "Payé"

  Achat({
    required this.id,
    required this.fournisseurNom,
    required this.fournisseurTelephone,
    required this.fournisseurEmail,
    required this.fournisseurAdresse,
    required this.date,
    required this.lignes,
    this.statut = 'Commandé',
  });

  double get total => lignes.fold(0, (sum, l) => sum + l.total);
}

/// ------------------ EMPLOYÉ ------------------
class Employe {
  String id;
  String nom;
  String role; // Administrateur, Pharmacien, Caissier, Gestionnaire
  String telephone;
  String statut; // Actif / Inactif

  Employe({
    required this.id,
    required this.nom,
    required this.role,
    required this.telephone,
    this.statut = 'Actif',
  });
}

/// ------------------ MOUVEMENT DE STOCK ------------------
enum TypeMouvement { entree, sortie, ajustement }

class MouvementStock {
  String id;
  DateTime date;
  String medicamentNom;
  TypeMouvement type;
  int quantite; // positif ou négatif selon le type
  String utilisateur;

  MouvementStock({
    required this.id,
    required this.date,
    required this.medicamentNom,
    required this.type,
    required this.quantite,
    required this.utilisateur,
  });
}

/// ------------------ UTILISATEUR ------------------
class User {
  String username;
  String name;
  String password;
  String role;
  String? imagePath;

  User({
    required this.username,
    required this.name,
    required this.password,
    required this.role,
    this.imagePath,
  });

  Map<String, dynamic> toMap() => {
    'username': username,
    'name': name,
    'password': password,
    'role': role,
    'imagePath': imagePath,
  };

  factory User.fromMap(Map<dynamic, dynamic> map) => User(
    username: map['username'],
    name: map['name'],
    password: map['password'],
    role: map['role'],
    imagePath: map['imagePath'],
  );
}
