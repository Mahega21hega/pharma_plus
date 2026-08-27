import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_data.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/medicaments_screen.dart';
import '../screens/ventes_screen.dart';
import '../screens/achats_screen.dart';
import '../screens/employes_screen.dart';
import '../screens/rapports_screen.dart';
import '../screens/parametres_screen.dart';

import '../screens/profile_screen.dart';

class ModuleItem {
  final String label;
  final IconData icon;
  final Widget Function() builder;
  const ModuleItem(this.label, this.icon, this.builder);
}

final List<ModuleItem> kModules = [
  ModuleItem('Tableau de bord', Icons.dashboard_rounded, () => const DashboardScreen()),
  ModuleItem('Médicaments', Icons.medication_rounded, () => const MedicamentsScreen()),
  ModuleItem('Ventes', Icons.point_of_sale_rounded, () => const VentesScreen()),
  ModuleItem('Achats', Icons.shopping_bag_rounded, () => const AchatsScreen()),
  ModuleItem('Employés', Icons.badge_rounded, () => const EmployesScreen()),
  ModuleItem('Rapports', Icons.bar_chart_rounded, () => const RapportsScreen()),
  ModuleItem('Paramètres', Icons.settings_rounded, () => const ParametresScreen()),
];

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selected = widget.initialIndex;

  void _select(int index, bool isDesktop) {
    setState(() => _selected = index);
    if (!isDesktop) {
      Navigator.of(context).maybePop(); // Ferme le drawer sur mobile
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Seuil de responsivité : 1000 pixels
        final bool isDesktop = constraints.maxWidth >= 1000;
        final module = kModules[_selected];

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                _buildSidebar(isDesktop),
                Expanded(
                  child: Column(
                    children: [
                      AppBar(
                        title: Text(module.label),
                        automaticallyImplyLeading: false,
                        actions: [_buildThemeAction()],
                      ),
                      Expanded(child: module.builder()),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          return Scaffold(
            appBar: AppBar(
              title: Text(module.label),
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              actions: [_buildThemeAction()],
            ),
            drawer: Drawer(
              child: _buildSidebar(isDesktop),
            ),
            body: module.builder(),
          );
        }
      },
    );
  }

  Widget _buildThemeAction() {
    return Consumer<AppData>(
      builder: (context, data, _) {
        final isDark = data.themeMode == ThemeMode.dark;
        return IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          tooltip: isDark ? 'Passer au mode clair' : 'Passer au mode sombre',
          onPressed: () => data.toggleTheme(),
        );
      },
    );
  }

  Widget _buildSidebar(bool isDesktop) {
    return Container(
      width: isDesktop ? 260 : null, // Largeur fixe seulement en mode desktop
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'PharmaFody',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 18, bottom: 10),
              child: Text('Gestion de Pharmacie',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: kModules.length,
                itemBuilder: (context, i) {
                  final selected = i == _selected;
                  
                  // Badge pour le stock et les alertes
                  int? badge;
                  if (kModules[i].label == 'Médicaments' || kModules[i].label == 'Tableau de bord') {
                    final data = context.read<AppData>();
                    badge = data.produitsEnRupture.length + data.produitsBientotExpires.length;
                    if (badge == 0) badge = null;
                  }

                  return ListTile(
                    selected: selected,
                    selectedTileColor: AppColors.sidebarSelected.withOpacity(0.18),
                    leading: Icon(kModules[i].icon,
                        color: selected ? Colors.white : Colors.white70, size: 20),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            kModules[i].label,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.white70,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badge',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _select(i, isDesktop),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Consumer<AppData>(
              builder: (context, data, _) {
                final user = data.currentUser;
                return ListTile(
                  onTap: () {
                    if (!isDesktop) Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.white24,
                    backgroundImage: user?.imagePath != null
                        ? (kIsWeb ? NetworkImage(user!.imagePath!) : FileImage(File(user!.imagePath!))) as ImageProvider
                        : null,
                    child: user?.imagePath == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    user?.name ?? 'Utilisateur',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    user?.role ?? 'Rôle',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
