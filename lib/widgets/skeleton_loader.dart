import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bloc de "skeleton loading" animé (pulsation douce), à utiliser à la place
/// d'un `CircularProgressIndicator` classique pendant le chargement de
/// contenu : montrer la forme approximative de ce qui va apparaître donne
/// une sensation de chargement plus rapide et évite l'écran qui "saute" une
/// fois les données arrivées.
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  const SkeletonBox({super.key, required this.height, this.width, this.borderRadius});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween(begin: 0.35, end: 0.7).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : AppColors.textMuted;
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: baseColor.withOpacity(_opacity.value * 0.16),
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Squelette d'une carte de liste (icône rond + 2 lignes de texte), pour les
/// écrans type "Médicaments" ou "Employés" pendant le premier chargement.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            const SkeletonBox(height: 40, width: 40, borderRadius: BorderRadius.all(Radius.circular(20))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, width: MediaQuery.of(context).size.width * 0.4),
                  const SizedBox(height: 8),
                  SkeletonBox(height: 11, width: MediaQuery.of(context).size.width * 0.25),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste de squelettes de cartes, pour remplacer l'écran vide/spinner
/// pendant le chargement initial d'une liste.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const SkeletonListTile(),
    );
  }
}

/// Squelette d'une carte statistique (comme celles du tableau de bord).
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 11, width: MediaQuery.of(context).size.width * 0.2),
            const SizedBox(height: 14),
            const SkeletonBox(height: 20, width: 90),
          ],
        ),
      ),
    );
  }
}
