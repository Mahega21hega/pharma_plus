import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

import 'profile_screen.dart';

class ParametresScreen extends StatelessWidget {
  const ParametresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SectionCard(
          title: 'Mon Profil',
          trailing: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: const Text('Gérer'),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(data.currentUser?.name ?? 'Admin'),
            subtitle: Text(data.currentUser?.role ?? 'Administrateur'),
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Informations de la pharmacie',
          child: Column(
            children: [
              _row('Nom de la pharmacie', data.nomPharmacie),
              _row('Adresse', 'Lot II K 45, Tananarive, Madagascar'),
              _row('Téléphone', '034 12 000 00'),
              _row('Email', 'contact@PharmaFody.mg'),
              _row('NIF', '3001234567'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Taxes et paiements',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('TVA activée (20%)'),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Paiement Mobile Money'),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Paiement par carte bancaire'),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Devise',
          child: DropdownButtonFormField<String>(
            value: 'Ariary (Ar)',
            decoration: const InputDecoration(labelText: 'Devise utilisée'),
            items: const [
              DropdownMenuItem(value: 'Ariary (Ar)', child: Text('Ariary (Ar)')),
              DropdownMenuItem(value: 'Euro (€)', child: Text('Euro (€)')),
              DropdownMenuItem(value: 'Dollar (\$)', child: Text('Dollar (\$)')),
            ],
            onChanged: (_) {},
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Sauvegarde et restauration',
          child: Column(
            children: [
              const Text('Dernière sauvegarde : aujourd\'hui, 22:30', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Sauvegarder maintenant'),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sauvegarde effectuée (démo)')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Restaurer une sauvegarde'),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
