import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/stat_card.dart';
import 'medicament_form_screen.dart';

final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: 'Ar', decimalDigits: 0);

/// Module fusionné "Médicaments" : regroupe la fiche produit (ex-module
/// Médicaments) et la gestion du stock (ex-module Stock) en un seul écran
/// à onglets, puisque stock/rupture/péremption sont des propriétés du
/// même objet [Medicament].
class MedicamentsScreen extends StatefulWidget {
  const MedicamentsScreen({super.key});

  @override
  State<MedicamentsScreen> createState() => _MedicamentsScreenState();
}

class _MedicamentsScreenState extends State<MedicamentsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);
  String _query = '';
  String _categorieFiltre = 'Toutes';

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicamentFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Material(
            color: isDark ? AppColors.cardDark : AppColors.card,
            child: TabBar(
              controller: _tabController,
              labelColor: isDark ? AppColors.primaryOnDark : AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: isDark ? AppColors.primaryOnDark : AppColors.primary,
              tabs: const [
                Tab(text: 'Liste'),
                Tab(text: 'Mouvements'),
                Tab(text: 'Alertes'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ListeTab(
                  query: _query,
                  categorieFiltre: _categorieFiltre,
                  onQueryChanged: (v) => setState(() => _query = v),
                  onCategorieChanged: (v) => setState(() => _categorieFiltre = v),
                ),
                const _MouvementsTab(),
                const _AlertesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglet "Liste" : fusion de l'ancien écran Médicaments (recherche, filtre
/// par catégorie, fiche produit, édition/suppression) et de l'ancien onglet
/// "Inventaire" du module Stock (ajustement rapide de la quantité,
/// import/export CSV).
class _ListeTab extends StatelessWidget {
  final String query;
  final String categorieFiltre;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategorieChanged;

  const _ListeTab({
    required this.query,
    required this.categorieFiltre,
    required this.onQueryChanged,
    required this.onCategorieChanged,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ['Toutes', ...{for (final m in data.medicaments) m.categorie}];

    final filtres = data.medicaments.where((m) {
      final matchQuery = query.isEmpty ||
          m.nomCommercial.toLowerCase().contains(query.toLowerCase()) ||
          m.dci.toLowerCase().contains(query.toLowerCase());
      final matchCat = categorieFiltre == 'Toutes' || m.categorie == categorieFiltre;
      return matchQuery && matchCat;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Rechercher (nom commercial, DCI)...',
                ),
                onChanged: onQueryChanged,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: categories
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c, style: const TextStyle(fontSize: 12)),
                              selected: categorieFiltre == c,
                              onSelected: (_) => onCategorieChanged(c),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: categorieFiltre == c
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : AppColors.textDark),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        Expanded(
          child: data.chargementInitial
              ? const SkeletonList()
              : filtres.isEmpty
                  ? const EmptyState(
                      icon: Icons.medication_outlined,
                      message: 'Aucun médicament trouvé.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
                      itemCount: filtres.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _MedicamentTile(medicament: filtres[i]),
                    ),
        ),
      ],
    );
  }
}

class _MedicamentTile extends StatelessWidget {
  final Medicament medicament;
  const _MedicamentTile({required this.medicament});

  @override
  Widget build(BuildContext context) {
    final m = medicament;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: const Icon(Icons.medication_rounded, color: AppColors.primary),
        ),
        title: Text(m.nomCommercial,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textLight : AppColors.textDark,
            )),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.dci} • ${m.categorie}', style: const TextStyle(fontSize: 12)),
            Row(
              children: [
                Text(_currency.format(m.prixVente),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                if (m.surOrdonnance) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.description_rounded, size: 13, color: AppColors.info),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Stock: ${m.stock}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: m.enRupture ? AppColors.danger : (isDark ? Colors.white70 : AppColors.textMuted),
                )),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MedicamentFormScreen(medicament: m)));
                } else if (v == 'delete') {
                  _confirmDelete(context, m);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Medicament m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le médicament'),
        content: Text('Voulez-vous vraiment supprimer "${m.nomCommercial}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              context.read<AppData>().supprimerMedicament(m.id);
              Navigator.pop(ctx);
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

/// Onglet "Mouvements" (inchangé, repris de l'ex-module Stock).
class _MouvementsTab extends StatelessWidget {
  const _MouvementsTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    if (data.mouvements.isEmpty) {
      return const EmptyState(
        icon: Icons.swap_vert_rounded,
        message: 'Aucun mouvement de stock enregistré.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: data.mouvements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final mv = data.mouvements[i];
        final isEntree = mv.type == TypeMouvement.entree;
        final isAjust = mv.type == TypeMouvement.ajustement;
        final color = isAjust ? AppColors.warning : (isEntree ? AppColors.primary : AppColors.danger);
        final label = isAjust ? 'Ajustement' : (isEntree ? 'Entrée' : 'Vente');
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(isEntree ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 18),
            ),
            title: Text(mv.medicamentNom, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${DateFormat('dd/MM/yyyy HH:mm').format(mv.date)} • ${mv.utilisateur}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${mv.quantite > 0 ? '+' : ''}${mv.quantite}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Onglet "Alertes" (inchangé, repris de l'ex-module Stock).
class _AlertesTab extends StatelessWidget {
  const _AlertesTab();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final rupture = data.produitsEnRupture;
    final expires = data.produitsBientotExpires;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SectionCard(
          title: 'Ruptures de stock (${rupture.length})',
          child: rupture.isEmpty
              ? const EmptyState(icon: Icons.check_circle_outline_rounded, message: 'Aucune rupture de stock.')
              : Column(
                  children: rupture
                      .map((m) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                            title: Text(m.nomCommercial),
                            trailing: Text('Stock: ${m.stock}', style: const TextStyle(color: AppColors.danger)),
                          ))
                      .toList(),
                ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Péremption proche (${expires.length})',
          child: expires.isEmpty
              ? const EmptyState(icon: Icons.check_circle_outline_rounded, message: 'Aucun produit proche de la péremption.')
              : Column(
                  children: expires
                      .map((m) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.access_time_filled_rounded, color: AppColors.warning),
                            title: Text(m.nomCommercial),
                            subtitle: Text('Lot ${m.numeroLot}'),
                            trailing: Text(DateFormat('dd/MM/yyyy').format(m.dateExpiration)),
                          ))
                      .toList(),
                ),
        ),
      ],
    );
  }
}
