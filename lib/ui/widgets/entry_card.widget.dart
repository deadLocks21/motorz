import 'package:flutter/material.dart';
import 'package:motorz/ui/theme/app_colors.dart';

/// Tuile uniforme de toutes les listes du véhicule (pleins, entretien, à prévoir,
/// pneus, cibles…) : carte avec icône colorée dans un carré arrondi, titre,
/// contenu secondaire (texte ou widget), trailing optionnel (coût, pastille,
/// actions…) et chevron signalant que la ligne ouvre quelque chose. Tap →
/// action principale.
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.showChevron = false,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;

  /// Affiche le chevron `›` (la ligne ouvre une page de détail). Pour les lignes
  /// qui ouvrent directement l'édition, on le laisse à false.
  final bool showChevron;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(color: colors.textMuted, fontSize: 12.5)),
                    ],
                    if (subtitleWidget != null) ...[
                      const SizedBox(height: 6),
                      subtitleWidget!,
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (showChevron) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: colors.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
