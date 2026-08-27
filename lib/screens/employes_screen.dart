import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

const _roles = ['Administrateur', 'Pharmacien', 'Caissier', 'Gestionnaire'];

class EmployesScreen extends StatelessWidget {
  const EmployesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Ajouter'),
        onPressed: () => _ouvrirFormulaire(context),
      ),
      body: data.employes.isEmpty
          ? const EmptyState(
              icon: Icons.badge_outlined,
              message: 'Aucun employé enregistré.\nAjoutez votre équipe avec le bouton ci-dessous.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              itemCount: data.employes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = data.employes[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF4F2),
                      child: Icon(Icons.badge_rounded, color: AppColors.primary),
                    ),
                    title: Text(e.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${e.role} • ${e.telephone}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (e.statut == 'Actif' ? AppColors.primary : AppColors.textMuted).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(e.statut,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: e.statut == 'Actif' ? AppColors.primary : AppColors.textMuted,
                                  fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          onPressed: () => _confirmerSuppression(context, e),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmerSuppression(BuildContext context, Employe e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet employé ?'),
        content: Text('${e.nom} sera retiré de la liste des employés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              context.read<AppData>().supprimerEmploye(e.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${e.nom} supprimé.')),
              );
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _ouvrirFormulaire(BuildContext context) {
    final nom = TextEditingController();
    final tel = TextEditingController();
    String role = _roles[1];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Ajouter un employé'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nom, decoration: const InputDecoration(labelText: 'Nom complet')),
              const SizedBox(height: 8),
              TextField(
                controller: tel,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Téléphone', hintText: '(+___) __ ___ ___'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setSt(() => role = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () {
                if (nom.text.isEmpty) return;
                final data = context.read<AppData>();
                data.ajouterEmploye(Employe(
                  id: data.genererId('EMP'),
                  nom: nom.text,
                  role: role,
                  telephone: tel.text,
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${nom.text} ajouté(e) à l\'équipe.')),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
