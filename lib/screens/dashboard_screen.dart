import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';

final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: 'Ar', decimalDigits: 0);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();

    if (data.chargementInitial) {
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: const [
              SkeletonStatCard(),
              SkeletonStatCard(),
              SkeletonStatCard(),
              SkeletonStatCard(),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(height: 220, borderRadius: BorderRadius.all(Radius.circular(14))),
          const SizedBox(height: 14),
          const SkeletonBox(height: 220, borderRadius: BorderRadius.all(Radius.circular(14))),
        ],
      );
    }

    final rupture = data.produitsEnRupture;
    final expires = data.produitsBientotExpires;
    final categories = data.ventesParCategorie;
    final totalCategories = categories.values.fold(0.0, (a, b) => a + b);
    // Une couleur bien distincte par catégorie, attribuée par ordre
    // d'apparition (et non par hash) pour éviter que deux catégories se
    // retrouvent avec la même couleur dans le camembert.
    final categoryColors = <String, Color>{
      for (final entry in categories.keys.toList().asMap().entries)
        entry.value: _paletteColor(entry.key),
    };
    final aucuneVente = data.ventes.isEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        final appData = context.read<AppData>();
        await Future.wait([
          appData.fetchMedicaments(),
          appData.fetchVentes(),
          appData.fetchAchats(),
          appData.fetchEmployes(),
          appData.fetchMouvements(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ---- Cartes statistiques ----
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              StatCard(
                title: "Chiffre d'affaires (jour)",
                value: _currency.format(data.chiffreAffairesJour),
                icon: Icons.attach_money_rounded,
                color: AppColors.primary,
                subtitle: 'Ventes totales aujourd\'hui',
              ),
              StatCard(
                title: 'Marge bénéficiaire (jour)',
                value: _currency.format(data.margeBeneficiaireJour),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF9B6BD9),
                subtitle: 'Bénéfice net estimé',
              ),
              StatCard(
                title: 'Ruptures de stock',
                value: '${rupture.length}',
                icon: Icons.warning_amber_rounded,
                color: AppColors.danger,
                subtitle: 'Produits épuisés',
              ),
              StatCard(
                title: 'Produits bientôt expirés',
                value: '${expires.length}',
                icon: Icons.access_time_filled_rounded,
                color: AppColors.warning,
                subtitle: 'À traiter rapidement',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---- Ventes 7 derniers jours ----
          SectionCard(
            title: 'Ventes (7 derniers jours)',
            child: SizedBox(
              height: 180,
              child: aucuneVente
                  ? const EmptyState(
                      icon: Icons.bar_chart_rounded,
                      message: 'Aucune vente enregistrée sur les 7 derniers jours.',
                    )
                  : BarChart(
                      BarChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                final day = DateTime.now().subtract(Duration(days: 6 - v.toInt()));
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(DateFormat('dd/MM').format(day),
                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: List.generate(7, (i) {
                          final values = data.ventesSeptJours;
                          return BarChartGroupData(x: i, barRods: [
                            BarChartRodData(toY: values[i], color: AppColors.primary, width: 22, borderRadius: BorderRadius.circular(4)),
                          ]);
                        }),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // ---- Répartition des ventes par catégorie ----
          SectionCard(
            title: 'Répartition des ventes par catégorie',
            child: categories.isEmpty
                ? const EmptyState(
                    icon: Icons.pie_chart_outline_rounded,
                    message: 'Aucune vente enregistrée pour le moment.',
                  )
                : Row(
                    children: [
                      SizedBox(
                        height: 140,
                        width: 140,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: categories.entries.map((e) {
                              final pct = totalCategories == 0 ? 0 : (e.value / totalCategories * 100);
                              final color = categoryColors[e.key]!;
                              return PieChartSectionData(
                                value: e.value,
                                color: color,
                                title: '${pct.toStringAsFixed(0)}%',
                                radius: 26,
                                titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: categories.entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: BoxDecoration(color: categoryColors[e.key], shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),

          // ---- Top 5 produits ----
          SectionCard(
            title: 'Top 5 des produits les plus vendus',
            child: data.topProduits.isEmpty
                ? const EmptyState(
                    icon: Icons.emoji_events_outlined,
                    message: 'Aucune vente enregistrée pour le moment.',
                  )
                : Column(
                    children: data.topProduits
                        .map((m) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.medication_rounded, color: AppColors.primary),
                              title: Text(m.nomCommercial),
                              subtitle: Text('Stock restant : ${m.stock}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              // Le volume vendu est l'info la plus pertinente
                              // d'un classement "Top produits" : on la met en
                              // avant plutôt que le stock restant.
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${data.quantiteVendue(m.id)}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                                  const Text('vendus', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 14),

          // ---- Produits bientôt expirés ----
          SectionCard(
            title: 'Produits bientôt expirés',
            child: expires.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    message: 'Aucun produit proche de la péremption.',
                  )
                : Column(
                    children: expires
                        .map((m) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.circle, color: AppColors.warning, size: 10),
                              title: Text(m.nomCommercial),
                              subtitle: Text('Lot ${m.numeroLot} • Exp. ${DateFormat('dd/MM/yyyy').format(m.dateExpiration)}'),
                              trailing: Text('${m.stock} u.', style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  /// Palette de couleurs volontairement variées (teintes bien séparées sur
  /// le cercle chromatique) pour que deux catégories voisines dans la liste
  /// ne se ressemblent jamais dans le camembert. Attribuée par index de
  /// catégorie plutôt que par hash, pour un rendu déterministe et sans
  /// collision tant qu'il y a moins de 12 catégories.
  static const List<Color> _categoryPalette = [
    AppColors.primary,
    Color(0xFF9B6BD9), // violet
    AppColors.danger,
    AppColors.warning,
    AppColors.info,
    Color(0xFFE0578C), // rose
    Color(0xFF2FA88A), // vert émeraude
    Color(0xFFC98A3B), // ocre
    Color(0xFF4C6EF5), // bleu indigo
    Color(0xFF6B7B78), // gris-vert
    Color(0xFFB5495B), // bordeaux
    Color(0xFF3BB4C6), // cyan
  ];

  Color _paletteColor(int index) => _categoryPalette[index % _categoryPalette.length];
}
