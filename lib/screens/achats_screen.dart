import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: 'Ar', decimalDigits: 0);

class AchatsScreen extends StatefulWidget {
  const AchatsScreen({super.key});

  @override
  State<AchatsScreen> createState() => _AchatsScreenState();
}

class _AchatsScreenState extends State<AchatsScreen> {
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Bon de commande'),
        onPressed: () => _ouvrirFormulaire(context),
      ),
      body: data.achats.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_bag_outlined,
              message: 'Aucun bon de commande.\nCréez-en un avec le bouton ci-dessous.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: data.achats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final a = data.achats[i];
                final statutColor = a.statut == 'Reçu' ? AppColors.primary : AppColors.warning;
                return Card(
                  child: ExpansionTile(
                    title: Text(a.fournisseurNom, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    subtitle: Text('${a.lignes.length} article(s) • ${DateFormat('dd/MM/yyyy').format(a.date)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statutColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(a.statut, style: TextStyle(color: statutColor, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tél : ${a.fournisseurTelephone}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            if (a.fournisseurEmail.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Email : ${a.fournisseurEmail}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ],
                            if (a.fournisseurAdresse.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Adresse : ${a.fournisseurAdresse}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ],
                            const SizedBox(height: 10),
                            ...a.lignes.map((ligne) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(ligne.medicamentNom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                      Text('${ligne.quantite} x ${_currency.format(ligne.prixUnitaire)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                    ],
                                  ),
                                )),
                            const Divider(height: 24),
                            Text('Total : ${_currency.format(a.total)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            if (a.statut == 'Commandé') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    context.read<AppData>().receptionnerAchat(a.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Commande réceptionnée et stock mis à jour.')),
                                    );
                                  },
                                  child: const Text('Confirmer la réception'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _ouvrirFormulaire(BuildContext context) {
    final data = context.read<AppData>();
    if (data.medicaments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun médicament disponible pour la commande.')));
      return;
    }

    String medicamentNom = data.medicaments.first.nomCommercial;
    final fournisseurNom = TextEditingController();
    bool erreurNom = false;
    bool erreurTelephone = false;
    final fournisseurTelephone = TextEditingController();
    final fournisseurEmail = TextEditingController();
    final fournisseurAdresse = TextEditingController();
    final qte = TextEditingController(text: '10');
    final List<LigneAchat> lignes = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setSt) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouveau bon de commande', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 20),
                const Text('FOURNISSEUR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                TextField(
                  controller: fournisseurNom,
                  decoration: InputDecoration(
                    labelText: 'Nom du fournisseur',
                    errorText: erreurNom ? 'Champ requis' : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fournisseurTelephone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Téléphone du fournisseur',
                    errorText: erreurTelephone ? 'Champ requis' : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fournisseurEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email du fournisseur'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: fournisseurAdresse,
                  decoration: const InputDecoration(labelText: 'Adresse du fournisseur'),
                ),
                const SizedBox(height: 24),
                const Text('ARTICLE À COMMANDER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: medicamentNom,
                  decoration: const InputDecoration(labelText: 'Médicament commandé'),
                  items: data.medicaments
                      .map((m) => DropdownMenuItem(value: m.nomCommercial, child: Text(m.nomCommercial)))
                      .toList(),
                  onChanged: (v) => setSt(() => medicamentNom = v!),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qte,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantité'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final quantite = int.tryParse(qte.text) ?? 0;
                        if (quantite <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quantité invalide')));
                          return;
                        }
                        final med = data.medicaments.firstWhere((m) => m.nomCommercial == medicamentNom);
                        setSt(() {
                          // ajouter la ligne au bon en cours
                          lignes.add(LigneAchat(medicamentNom: medicamentNom, quantite: quantite, prixUnitaire: med.prixAchat));
                          qte.text = '10';
                        });
                      },
                      child: const Text('Ajouter la ligne'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (lignes.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Articles ajoutés', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...lignes.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ligne = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text('${ligne.medicamentNom} • ${ligne.quantite}')), 
                              IconButton(
                                onPressed: () => setSt(() => lignes.removeAt(idx)),
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                    ],
                  ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final nom = fournisseurNom.text.trim();
                      final telephone = fournisseurTelephone.text.trim();
                      final email = fournisseurEmail.text.trim();
                      final adresse = fournisseurAdresse.text.trim();

                      final nomVide = nom.isEmpty;
                      final telVide = telephone.isEmpty;
                      if (nomVide || telVide) {
                        setSt(() {
                          erreurNom = nomVide;
                          erreurTelephone = telVide;
                        });
                        return;
                      }

                      // si aucune ligne ajoutée via +, prendre la ligne courante
                      final List<LigneAchat> finalLignes = [];
                      if (lignes.isNotEmpty) {
                        finalLignes.addAll(lignes);
                      } else {
                        final quantite = int.tryParse(qte.text) ?? 0;
                        if (quantite <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Veuillez renseigner une quantité valide.')),
                          );
                          return;
                        }
                        final med = data.medicaments.firstWhere((m) => m.nomCommercial == medicamentNom);
                        finalLignes.add(LigneAchat(medicamentNom: medicamentNom, quantite: quantite, prixUnitaire: med.prixAchat));
                      }

                      data.ajouterAchat(Achat(
                        id: data.genererId('ACH'),
                        fournisseurNom: nom,
                        fournisseurTelephone: telephone,
                        fournisseurEmail: email,
                        fournisseurAdresse: adresse,
                        date: DateTime.now(),
                        lignes: finalLignes,
                      ));

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bon de commande enregistré.')),
                        );
                      }
                    },
                    child: const Text('Créer le bon de commande'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
