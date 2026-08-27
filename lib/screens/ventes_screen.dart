import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

import '../services/pdf_service.dart';

final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: 'Ar', decimalDigits: 0);

/// Largeur en dessous de laquelle on bascule sur une mise en page mobile
/// (liste + panier empilés) plutôt qu'une mise en page côte-à-côte.
const double _mobileBreakpoint = 700;

class VentesScreen extends StatefulWidget {
  const VentesScreen({super.key});

  @override
  State<VentesScreen> createState() => _VentesScreenState();
}

class _VentesScreenState extends State<VentesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final resultats = data.medicaments
        .where((m) =>
            _query.isEmpty ||
            m.nomCommercial.toLowerCase().contains(_query.toLowerCase()) ||
            m.codeBarres.contains(_query))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;

        if (!isMobile) {
          // ---- Grand écran : liste produits + panier côte à côte ----
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: _ProductList(
                  query: _query,
                  onQueryChanged: (v) => setState(() => _query = v),
                  resultats: resultats,
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(
                width: 380,
                child: _PanierPanel(scrollController: null),
              ),
            ],
          );
        }

        // ---- Mobile : liste produits pleine largeur + panier flottant ----
        return _FloatingCartLayout(
          query: _query,
          onQueryChanged: (v) => setState(() => _query = v),
          resultats: resultats,
        );
      },
    );
  }
}

// =====================================================================
// STYLE A — Barre panier flottante + fiche panier plein écran
// =====================================================================
class _FloatingCartLayout extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<Medicament> resultats;
  const _FloatingCartLayout({
    required this.query,
    required this.onQueryChanged,
    required this.resultats,
  });

  void _ouvrirFichePanier(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: Container(
                color: isDark ? AppColors.cardDark : AppColors.card,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: _PanierPanel(scrollController: scrollController),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return Stack(
      children: [
        Padding(
          // Espace réservé en bas pour ne pas que la barre flottante cache
          // le dernier élément de la liste.
          padding: EdgeInsets.only(bottom: data.panier.isEmpty ? 0 : 88),
          child: _ProductList(
            query: query,
            onQueryChanged: onQueryChanged,
            resultats: resultats,
          ),
        ),
        if (data.panier.isNotEmpty)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _FloatingCartBar(onTap: () => _ouvrirFichePanier(context)),
          ),
      ],
    );
  }
}

class _FloatingCartBar extends StatelessWidget {
  final VoidCallback onTap;
  const _FloatingCartBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final nbArticles = data.panier.fold<int>(0, (sum, i) => sum + i.quantite);

    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      elevation: 8,
      shadowColor: AppColors.primary.withOpacity(0.4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 24),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '$nbArticles',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$nbArticles article${nbArticles > 1 ? 's' : ''} dans le panier',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _currency.format(data.totalPanier),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const Text(
                'Voir le panier',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Liste de produits (partagée par toutes les mises en page)
// =====================================================================
class _ProductList extends StatelessWidget {
  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<Medicament> resultats;
  const _ProductList({
    required this.query,
    required this.onQueryChanged,
    required this.resultats,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Rechercher un médicament (nom, code-barres...)',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => onQueryChanged(''),
                    ),
            ),
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: resultats.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  message: data.medicaments.isEmpty
                      ? 'Aucun médicament enregistré.\nAjoutez-en depuis le module Médicaments.'
                      : 'Aucun résultat pour cette recherche.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: resultats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ProductCard(medicament: resultats[i]),
                ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Medicament medicament;
  const _ProductCard({required this.medicament});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enPanier = data.panier.where((i) => i.medicamentId == medicament.id).fold<int>(0, (s, i) => s + i.quantite);
    final rupture = medicament.stock <= 0;
    final stockBas = !rupture && medicament.stock <= medicament.stockMin;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicament.nomCommercial,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? AppColors.textLight : AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          medicament.dci,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StockChip(rupture: rupture, stockBas: stockBas, stock: medicament.stock),
                      if (medicament.surOrdonnance) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.assignment_late_rounded, size: 13, color: AppColors.warning),
                      ],
                    ],
                  ),
                  if (enPanier > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$enPanier déjà dans le panier',
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currency.format(medicament.prixVente),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                _AddButton(
                  disabled: rupture,
                  onPressed: () {
                    // `ajouterAuPanier` refuse désormais (retourne `false`)
                    // si le stock disponible est déjà entièrement dans le
                    // panier, pour ne plus pouvoir vendre plus que ce qui
                    // est en rayon.
                    final ok = context.read<AppData>().ajouterAuPanier(medicament);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(milliseconds: 900),
                        width: 220,
                        backgroundColor: ok ? AppColors.textDark : AppColors.danger,
                        content: Row(
                          children: [
                            Icon(
                              ok ? Icons.check_circle_rounded : Icons.error_rounded,
                              color: ok ? AppColors.primary : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ok ? '${medicament.nomCommercial} ajouté' : 'Stock insuffisant',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  final bool rupture;
  final bool stockBas;
  final int stock;
  const _StockChip({required this.rupture, required this.stockBas, required this.stock});

  @override
  Widget build(BuildContext context) {
    final Color color = rupture ? AppColors.danger : (stockBas ? AppColors.warning : AppColors.primary);
    final String label = rupture ? 'Rupture' : 'Stock $stock';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool disabled;
  final VoidCallback onPressed;
  const _AddButton({required this.disabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 34),
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(disabled ? Icons.block_rounded : Icons.add_rounded, size: 16),
        label: Text(disabled ? 'Rupture' : 'Ajouter', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// =====================================================================
// Panneau panier (contenu partagé par la fiche plein écran et le panneau
// persistant)
// =====================================================================
class _PanierPanel extends StatelessWidget {
  final ScrollController? scrollController;
  final bool showDragHandle;
  const _PanierPanel({required this.scrollController, this.showDragHandle = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nbArticles = data.panier.fold<int>(0, (sum, i) => sum + i.quantite);

    return Container(
      color: (scrollController != null || showDragHandle) ? Colors.transparent : (isDark ? AppColors.cardDark : AppColors.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDragHandle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      nbArticles > 0 ? 'Panier ($nbArticles)' : 'Panier',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isDark ? AppColors.textLight : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                if (data.panier.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => context.read<AppData>().viderPanier(),
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                    label: const Text('Vider', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: data.panier.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    message: 'Le panier est vide.\nAjoutez des médicaments depuis la liste.',
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    itemCount: data.panier.length,
                    separatorBuilder: (_, __) => const Divider(height: 18),
                    itemBuilder: (context, i) => _CartItemRow(item: data.panier[i]),
                  ),
          ),
          _CartFooter(),
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final VenteItem item;
  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nom,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textLight : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_currency.format(item.prixUnitaire)} / unité',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              if (item.requiresOrdonnance) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => context.read<AppData>().definirOrdonnanceValide(item.medicamentId, !item.ordonnanceValide),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: (item.ordonnanceValide ? AppColors.primary : AppColors.danger).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.ordonnanceValide ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          size: 14,
                          color: item.ordonnanceValide ? AppColors.primary : AppColors.danger,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.ordonnanceValide ? 'Ordonnance validée' : 'Ordonnance à valider',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: item.ordonnanceValide ? AppColors.primary : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currency.format(item.sousTotal),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            _QuantityStepper(item: item),
          ],
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final VenteItem item;
  const _QuantityStepper({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF2F4F3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperButton(
            icon: item.quantite <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            color: item.quantite <= 1 ? AppColors.danger : (isDark ? Colors.white70 : AppColors.textDark),
            onTap: () {
              if (item.quantite <= 1) {
                context.read<AppData>().retirerDuPanier(item.medicamentId);
              } else {
                context.read<AppData>().changerQuantitePanier(item.medicamentId, -1);
              }
            },
          ),
          SizedBox(
            width: 26,
            child: Text(
              '${item.quantite}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isDark ? AppColors.textLight : AppColors.textDark,
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.add_rounded,
            color: AppColors.primary,
            onTap: () {
              final ok = context.read<AppData>().changerQuantitePanier(item.medicamentId, 1);
              if (!ok) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stock insuffisant pour cette quantité.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE7ECEA))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        children: [
          _ligneTotal('Sous-total', _currency.format(data.sousTotalPanier), isDark: isDark),
          if (data.remiseEnCours > 0)
            _ligneTotal('Remise (${data.remiseEnCours.toStringAsFixed(0)}%)', '- ${_currency.format(data.remiseMontantPanier)}', isDark: isDark, color: AppColors.danger),
          const SizedBox(height: 4),
          _ligneTotal('Total', _currency.format(data.totalPanier), gras: true, isDark: isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: data.panier.isEmpty ? null : () => _ouvrirRemise(context),
                  icon: const Icon(Icons.percent_rounded, size: 16),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    foregroundColor: isDark ? Colors.white70 : AppColors.textDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text('Remise'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: data.panier.isEmpty ? null : () => _validerPanier(context),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  label: const Text('Paiement', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ligneTotal(String label, String value, {bool gras = false, required bool isDark, Color? color}) {
    final baseColor = isDark ? AppColors.textLight : AppColors.textDark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: gras ? FontWeight.w700 : FontWeight.w400,
            fontSize: gras ? 16 : 13,
            color: gras ? baseColor : (isDark ? Colors.white70 : AppColors.textMuted),
          )),
          Text(value, style: TextStyle(
            fontWeight: gras ? FontWeight.w800 : FontWeight.w600,
            fontSize: gras ? 17 : 13,
            color: color ?? baseColor,
          )),
        ],
      ),
    );
  }

  void _validerPanier(BuildContext context) {
    final data = context.read<AppData>();
    if (data.ordonnanceItemsNonValides.isNotEmpty) {
      final produits = data.ordonnanceItemsNonValides.map((item) => item.nom).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Validation manquante pour : $produits')),
      );
      return;
    }
    _ouvrirPaiement(context);
  }

  void _ouvrirRemise(BuildContext context) {
    final data = context.read<AppData>();
    double remise = data.remiseEnCours;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appliquer une remise'),
        content: StatefulBuilder(
          builder: (ctx, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${remise.toStringAsFixed(0)} %', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              Slider(
                value: remise,
                min: 0,
                max: 30,
                divisions: 30,
                label: '${remise.toStringAsFixed(0)}%',
                onChanged: (v) => setSt(() => remise = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              data.definirRemise(remise);
              Navigator.pop(ctx);
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  void _ouvrirPaiement(BuildContext context) {
    final data = context.read<AppData>();
    String mode = 'Espèces';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Paiement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 12),
                Text('Total à payer : ${_currency.format(data.totalPanier)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 16)),
                const SizedBox(height: 14),
                const Text('Méthode de paiement', style: TextStyle(fontWeight: FontWeight.w600)),
                ...['Espèces', 'Carte bancaire', 'Mobile Money'].map(
                  (m) => RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: m,
                    groupValue: mode,
                    title: Text(m),
                    onChanged: (v) => setSt(() => mode = v!),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      // `encaisser` peut lever une exception (ordonnance non
                      // validée, stock insuffisant...) : avant ce correctif,
                      // rien n'était catché et le bouton ne faisait
                      // silencieusement rien en cas de problème.
                      final Vente vente;
                      try {
                        vente = await data.encaisser(modePaiement: mode);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.danger,
                              content: Text(e.toString().replaceFirst('Exception: ', '')),
                            ),
                          );
                        }
                        return;
                      }
                      if (context.mounted) Navigator.pop(ctx);
                      if (context.mounted) Navigator.of(context, rootNavigator: true).maybePop();

                      // Demander si on veut imprimer
                      if (context.mounted) {
                        final bool? print = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Vente réussie'),
                            content: const Text('Voulez-vous imprimer le ticket de caisse ?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
                              ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui, imprimer')),
                            ],
                          ),
                        );

                        if (print == true) {
                          await PdfService.generateReceipt(vente, data.nomPharmacie);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Vente ${vente.id} encaissée — ${_currency.format(vente.total)}')),
                          );
                        }
                      }
                    },
                    child: const Text('Encaisser'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
