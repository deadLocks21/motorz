import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motorz/core/application/services/diagnostic.service.dart';
import 'package:motorz/core/application/services/diagnostic_report.service.dart';
import 'package:motorz/core/domain/model/diagnostic_code.dart';
import 'package:motorz/core/domain/model/diagnostic_session.dart';
import 'package:motorz/core/domain/model/media_item.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_diagnostic_sheet.widget.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/add_plan_sheet.widget.dart';
import 'package:motorz/ui/pages/vehicle_detail/widgets/documents_tab.widget.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';
import 'package:motorz/ui/theme/app_colors.dart';
import 'package:motorz/ui/utils/format.dart';

/// Détail d'une session de diagnostic : ce qui a été lu, ce qui a été trouvé,
/// et le rapport d'origine conservé (§5.11).
class DiagnosticDetailPage extends ConsumerStatefulWidget {
  const DiagnosticDetailPage({super.key, required this.session});
  final DiagnosticSession session;

  @override
  ConsumerState<DiagnosticDetailPage> createState() => _DiagnosticDetailPageState();
}

class _DiagnosticDetailPageState extends ConsumerState<DiagnosticDetailPage> {
  late DiagnosticSession _session;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Future<void> _edit() async {
    await showDiagnosticSheet(
      context,
      ref,
      vehicleId: _session.vehicleId.value,
      existing: _session,
    );
    final updated =
        await ref.read(diagnosticSessionRepositoryProvider).getById(_session.id.value);
    if (!mounted) return;
    // Session supprimée depuis la feuille : on ferme, il n'y a plus rien à voir.
    if (updated == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _session = updated);
  }

  /// Analyse un rapport **PDF** joint : l'API en extrait le texte, que le même
  /// analyseur que pour un rapport collé dépouille ici. Sans réseau, le document
  /// reste joint et la session reste « à analyser » — rien n'est perdu.
  Future<void> _analyzePdf(MediaItem pdf) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _analyzing = true);
    try {
      final text = await ref.read(mediaRemoteApiProvider).extractText(pdf.id.value);
      if (text == null || text.trim().isEmpty) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Ce PDF n\'a pas de couche texte (scan) : saisis les codes à la main.'),
        ));
        return;
      }

      final parsed = DiagnosticReportParser.parse(text);
      final now = DateTime.now().toUtc();
      final updated = _session.copyWith(
        rawText: text,
        analyzedAt: now,
        // Le rapport vient d'un PDF : la session le dit, même si elle a été
        // créée « à la main » en attendant que le document soit joint.
        source: DiagnosticSource.pdf,
        tool: _session.tool ?? parsed.tool,
        connectionProfile: _session.connectionProfile ?? parsed.connectionProfile,
        modulesScanned: parsed.modules.isEmpty ? _session.modulesScanned : parsed.modules,
        updatedAt: now,
      );
      await ref.read(diagnosticSessionRepositoryProvider).save(updated);

      // Ré-analyser remplace les codes : on ne les empile pas.
      final repo = ref.read(diagnosticCodeRepositoryProvider);
      for (final old in (await repo.listAll()).where((c) => c.sessionId == _session.id)) {
        await repo.delete(old);
      }
      for (final c in parsed.codes) {
        await repo.save(DiagnosticCode(
          id: UuidValue.generate(),
          sessionId: _session.id,
          code: c.code,
          module: c.module,
          description: c.description,
          status: c.status,
          rawStatus: c.rawStatus,
          updatedAt: now,
        ));
      }

      if (!mounted) return;
      setState(() => _session = updated);
      messenger.showSnackBar(SnackBar(
        content: Text('${parsed.distinctCodes.length} défaut(s) lus dans le PDF.'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Analyse impossible hors ligne — le PDF reste joint, réessaie connecté.'),
      ));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  /// Depuis un code, on crée une **tâche ponctuelle** pré-remplie : le pont vers
  /// l'entretien passe par le mécanisme existant, sans lien stocké entre un code
  /// et une opération.
  Future<void> _planRepair(GroupedCode code) async {
    final title = code.description == null
        ? 'Diagnostiquer ${code.code}'
        : '${code.code} — ${code.description}';
    await showPlanSheet(context, ref, vehicleId: _session.vehicleId.value, prefilledTitle: title);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final codes = ref.watch(codesForSessionProvider(_session.id.value)).value ?? const [];
    final grouped = DiagnosticService.groupBySession(codes);
    final isBattery = _session.type == DiagnosticType.battery;

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.type.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      formatDate(_session.date),
                      if (_session.odometer != null) formatKm(_session.odometer),
                    ].join(' · '),
                    style: TextStyle(color: colors.textMuted),
                  ),
                  if (_session.tool != null) ...[
                    const SizedBox(height: 6),
                    Text(_session.tool!),
                  ],
                  if (_session.connectionProfile != null)
                    Text(_session.connectionProfile!, style: TextStyle(color: colors.textMuted)),
                  if (_session.summary != null) ...[
                    const SizedBox(height: 10),
                    Text(_session.summary!,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                  if (_session.notes != null) ...[
                    const SizedBox(height: 8),
                    Text(_session.notes!),
                  ],
                  if (_session.isPendingAnalysis) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.hourglass_empty, size: 16, color: colors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Rapport à analyser',
                              style: TextStyle(color: colors.textMuted)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (isBattery) ..._batterySection(colors) else ..._obdSection(grouped, colors),
          const SizedBox(height: 20),
          Text('Documents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          MediaGrid(ownerType: 'diagnostic_session', ownerId: _session.id.value),
          ..._pdfAnalysisActions(),
          if (_session.sourceUrl != null) ...[
            const SizedBox(height: 20),
            _SourceLink(url: _session.sourceUrl!, colors: colors),
          ],
          if (_session.rawText != null) ...[
            const SizedBox(height: 20),
            _RawReport(text: _session.rawText!, colors: colors),
          ],
        ],
      ),
    );
  }

  /// Bouton d'analyse d'un rapport PDF joint (un par PDF, l'un peut être la
  /// facture et l'autre le rapport).
  List<Widget> _pdfAnalysisActions() {
    final media = ref.watch(mediaForOwnerProvider(_session.id.value)).value ?? const <MediaItem>[];
    final pdfs = media.where((m) => m.kind == 'pdf' && m.deletedAt == null).toList();
    if (pdfs.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      for (final pdf in pdfs)
        OutlinedButton.icon(
          key: Key('analyzePdf_${pdf.id.value}'),
          onPressed: _analyzing ? null : () => _analyzePdf(pdf),
          icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: Text('Analyser ${pdf.originalFilename ?? 'le PDF'}'),
        ),
    ];
  }

  List<Widget> _batterySection(AppColors colors) {
    final measurements = _session.measurements;
    if (measurements == null || measurements.isEmpty) {
      return [
        Text('Aucune mesure enregistrée.', style: TextStyle(color: colors.textMuted)),
      ];
    }
    return [
      Text('Mesures', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              for (final entry in measurements.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(batteryMeasurementLabel(entry.key),
                          style: TextStyle(color: colors.textMuted)),
                      Text(formatBatteryMeasurement(entry.key, entry.value),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _obdSection(List<GroupedCode> grouped, AppColors colors) {
    return [
      Row(
        children: [
          Expanded(
            child: Text('Défauts (${grouped.length})',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (grouped.isEmpty)
        Text(
          _session.analyzedAt == null
              ? 'Rapport pas encore analysé.'
              : 'Aucun code défaut — tout est propre.',
          style: TextStyle(color: colors.textMuted),
        )
      else
        ...grouped.map((g) => _CodeTile(
              grouped: g,
              colors: colors,
              onPlan: () => _planRepair(g),
            )),
      if (_session.modulesScanned.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Calculateurs interrogés', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Ce qui a été lu — et donc ce qu\'un prochain relevé pourra confirmer.',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final module in _session.modulesScanned)
              Chip(
                label: Text(module),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
    ];
  }
}

/// Un défaut, avec les calculateurs qui l'ont remonté. Le même code vu par cinq
/// modules tient sur une ligne.
class _CodeTile extends StatelessWidget {
  const _CodeTile({required this.grouped, required this.colors, required this.onPlan});
  final GroupedCode grouped;
  final AppColors colors;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(grouped.code,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(width: 8),
                _StatusPill(status: grouped.status, colors: colors),
                const Spacer(),
                IconButton(
                  tooltip: 'Prévoir la réparation',
                  icon: const Icon(Icons.playlist_add, size: 20),
                  onPressed: onPlan,
                ),
              ],
            ),
            if (grouped.description != null)
              Text(grouped.description!, style: TextStyle(color: colors.textPrimary)),
            if (grouped.modules.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                grouped.modules.length == 1
                    ? grouped.modules.single
                    : '${grouped.modules.length} calculateurs : ${grouped.modules.join(', ')}',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.colors});
  final DiagnosticCodeStatus status;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    // Même code couleur que les échéances : un défaut confirmé se lit comme un
    // « en retard », une simple attente comme un « bientôt dû ».
    final color = switch (status) {
      DiagnosticCodeStatus.permanent || DiagnosticCodeStatus.confirmed => colors.statusOverdue,
      DiagnosticCodeStatus.pending => colors.statusSoon,
      DiagnosticCodeStatus.unknown => colors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// Lien du rapport d'origine : gardé comme trace de la source. Copiable — on ne
/// l'ouvre pas à la place de l'utilisateur.
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.url, required this.colors});
  final String url;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.link),
        title: const Text('Rapport d\'origine'),
        subtitle: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          tooltip: 'Copier le lien',
          icon: const Icon(Icons.copy_outlined),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Lien copié')));
          },
        ),
      ),
    );
  }
}

/// Rapport brut, replié : conservé pour pouvoir le ré-analyser plus tard.
class _RawReport extends StatelessWidget {
  const _RawReport({required this.text, required this.colors});
  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Rapport d\'origine'),
        subtitle: Text('Conservé pour ré-analyse', style: TextStyle(color: colors.textMuted)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
