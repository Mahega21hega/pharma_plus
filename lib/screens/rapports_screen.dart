import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: 'Ar', decimalDigits: 0);

class RapportsScreen extends StatelessWidget {
  const RapportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final totalVentes = data.ventes.fold(0.0, (s, v) => s + v.total);
    final nbVentes = data.ventes.length;
    final panierMoyen = nbVentes == 0 ? 0.0 : totalVentes / nbVentes;
    final beneficeBrut = data.ventes.fold(0.0, (s, v) {
      double benef = 0;
      for (final item in v.items) {
        final med = data.medicaments.firstWhere((m) => m.nomCommercial == item.nom, orElse: () => data.medicaments.first);
        benef += (item.prixUnitaire - med.prixAchat) * item.quantite;
      }
      return s + benef;
    });

    final topProduits = data.topProduits;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: [
            StatCard(title: 'Ventes totales', value: _currency.format(totalVentes), icon: Icons.trending_up_rounded, color: AppColors.primary),
            StatCard(title: 'Nombre de ventes', value: '$nbVentes', icon: Icons.receipt_rounded, color: AppColors.info),
            StatCard(title: 'Bénéfice brut', value: _currency.format(beneficeBrut), icon: Icons.savings_rounded, color: AppColors.warning),
            StatCard(title: 'Panier moyen', value: _currency.format(panierMoyen), icon: Icons.shopping_basket_rounded, color: Color(0xFF9B6BD9)),
          ],
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Évolution des ventes',
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(data.ventesSeptJours.length, (i) => FlSpot(i.toDouble(), data.ventesSeptJours[i])),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Top produits vendus',
          child: Column(
            children: topProduits.isEmpty
                ? [const Text('Aucune donnée', style: TextStyle(color: AppColors.textMuted))]
                : topProduits
                    .map((m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.medication_rounded, color: AppColors.primary),
                          title: Text(m.nomCommercial),
                          subtitle: Text(_currency.format(m.prixVente), style: const TextStyle(fontSize: 12)),
                          // La quantité vendue est l'information la plus
                          // pertinente d'un classement "Top produits" : elle
                          // est mise en avant en gros/gras, le prix passe en
                          // sous-titre secondaire.
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
        SectionCard(
          title: 'Exporter le rapport',
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await PdfService.generateReport(
                  data.nomPharmacie,
                  totalVentes,
                  nbVentes,
                  beneficeBrut,
                  topProduits,
                  data.quantiteVendue,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapport PDF généré.')));
                }
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Générer le rapport PDF'),
            ),
          ),
        ),
      ],
    );
  }
}
