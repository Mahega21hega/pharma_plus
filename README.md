# PharmaFody – Application Flutter de gestion de pharmacie

Application **Flutter** de gestion de pharmacie (dashboard, médicaments, stock, ventes/POS,
clients, ordonnances, achats, fournisseurs, employés, rapports), développée dans le cadre
d'un projet de tech web mobile (L3, ENI Antananarivo).

## 1. Installation

Les dossiers natifs (`android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`) sont déjà
inclus dans le dépôt. Pour lancer le projet :

```bash
# 1. Installez Flutter (https://docs.flutter.dev/get-started/install) si ce n'est pas déjà fait
flutter --version

# 2. Depuis ce dossier, installez les dépendances
flutter pub get

# 3. Lancez l'application (émulateur, appareil connecté, Chrome ou desktop)
flutter run
```

Aucun backend ni base de données externe à démarrer : toutes les données sont persistées
localement via SQLite (`sqflite` / `sqflite_common_ffi`, base en version 3). Au premier
lancement, un compte administrateur par défaut est créé (`admin` / `admin`) et la base
démarre vide (aucune donnée métier pré-remplie).

## 2. Architecture du projet

```
lib/
 ├── main.dart                     # Point d'entrée, MaterialApp + Provider
 ├── theme/app_theme.dart          # Couleurs/thème
 ├── models/models.dart            # Medicament, Client, Vente, Ordonnance,
 │                                  # Fournisseur, Achat, Employe, MouvementStock, User
 ├── providers/app_data.dart       # État global de l'app (données + logique métier)
 ├── services/
 │    ├── local_database.dart      # Persistance SQLite locale (sqflite), 10 tables
 │    ├── pdf_service.dart         # Génération de reçus PDF
 │    └── csv_service.dart         # Import/export CSV
 ├── widgets/
 │    ├── app_shell.dart           # Drawer (menu latéral) + barre de navigation
 │    ├── stat_card.dart           # Cartes statistiques / sections réutilisables
 │    └── empty_state.dart         # État vide réutilisable
 └── screens/
      ├── login_screen.dart / signup_screen.dart / profile_screen.dart
      ├── dashboard_screen.dart         # Tableau de bord (KPIs, graphiques)
      ├── medicaments_screen.dart       # Gestion des médicaments (liste + recherche)
      ├── medicament_form_screen.dart   # Ajout / modification d'un médicament
      ├── stock_screen.dart             # Gestion du stock (inventaire, mouvements, alertes)
      ├── ventes_screen.dart            # Ventes / POS (recherche, panier, client, paiement)
      ├── clients_screen.dart           # Clients (fiche, points fidélité, historique d'achats)
      ├── ordonnances_screen.dart       # Ordonnances (médecin, médicaments prescrits, photo)
      ├── achats_screen.dart            # Achats (bons de commande, réception)
      ├── fournisseurs_screen.dart      # Carnet de fournisseurs
      ├── employes_screen.dart          # Employés (rôles, statut)
      ├── rapports_screen.dart          # Rapports (ventes, bénéfices, top produits)
      └── parametres_screen.dart        # Paramètres (thème, infos pharmacie...)
```

## 3. Choix techniques

- **State management : `provider`** — un seul `ChangeNotifier` (`AppData`) contient toutes
  les données (médicaments, ventes, achats, clients, fournisseurs, ordonnances, employés...)
  et la logique métier (panier, décrémentation du stock à la vente, points de fidélité,
  alertes de rupture/péremption...).
- **Persistance : `sqflite`** — base de données SQLite locale (`lib/services/local_database.dart`),
  avec bascule automatique sur `sqflite_common_ffi` sur desktop (Windows/Linux/macOS).
  Les clés étrangères (`ON DELETE CASCADE` pour les lignes de vente/achat/ordonnance) sont
  activées explicitement via `PRAGMA foreign_keys = ON`.
- **Module Clients/Fournisseurs/Ordonnances** : fiche client avec historique d'achats et
  points de fidélité (1 point / 10 000 Ar dépensés), carnet de fournisseurs réutilisable
  depuis le formulaire d'achat (avec auto-enregistrement des nouveaux fournisseurs saisis
  manuellement), ordonnances avec prescriptions multiples et statut utilisée/disponible.
- **Layout adaptatif** — arbres de widgets distincts desktop/mobile (bascule au seuil
  900–1000px), avec un écran Ventes en split-panel sur desktop et en bottom-sheet de
  paiement sur mobile.
- **Graphiques** : `fl_chart`.
- **PDF / CSV** : `pdf` + `printing` pour les reçus, `csv` + `file_picker` pour l'import/export.
- **Photo** : `image_picker` pour joindre la photo d'une ordonnance.

## 4. Lien avec le cours (natif vs hybride)

Ce projet utilise **Flutter**, un framework qui compile vers du code natif (contrairement à
une approche hybride type **Apache Cordova**, qui embarque une WebView) : une seule base de
code Dart pour Android/iOS/desktop, un rendu natif (pas de WebView).

## 5. Limitations connues / pour aller plus loin

- Les achats rapprochent le fournisseur par **nom** (`fournisseurNom`), pas par
  `fournisseurId` — un renommage de fournisseur dans le module Fournisseurs ne met donc pas
  à jour rétroactivement les bons de commande déjà passés. Migrer vers une vraie clé
  étrangère `fournisseurId` serait la suite logique si le volume de données grossit.
- Gestion fine des rôles (Administrateur / Pharmacien / Caissier / Gestionnaire) : le champ
  `role` existe sur `Employe`/`User` mais n'est pas encore utilisé pour restreindre l'accès
  aux écrans.
